import XCTest
import CoreGraphics
@testable import NewsFeedSupport

/// The skeleton (Feed2 Skeleton.swift), positioned from the measured model row.
final class NewsSkeletonShapesTests: XCTestCase {
    private let modelRow = NewsSkeletonModelRow(
        height: 96.0,
        avatarFrame: CGRect(x: 16.0, y: 11.0, width: 16.0, height: 16.0),
        titleFrame: CGRect(x: 36.0, y: 10.0, width: 130.0, height: 18.0),
        textLineFrames: [CGRect(x: 16.0, y: 30.0, width: 360.0, height: 18.0), CGRect(x: 16.0, y: 50.0, width: 355.0, height: 18.0), CGRect(x: 16.0, y: 70.0, width: 200.0, height: 18.0)],
        textWidth: 370.0,
        thumbnailFrame: nil
    )

    func testEveryThirdRowHasNoThumbnail() {
        XCTAssertEqual((0 ..< 7).map(newsSkeletonRowHasThumbnail(index:)), [false, true, true, false, true, true, false])
    }

    func testPhotoRowNarrowsTheTextAndAddsTheThumbnail() {
        let photo = newsSkeletonPhotoRow(from: self.modelRow, width: 402.0)
        XCTAssertEqual(photo.textWidth, 272.0)
        XCTAssertEqual(photo.thumbnailFrame, CGRect(x: 304.0, y: 8.0, width: 82.0, height: 82.0))
        XCTAssertEqual(photo.height, 98.0)
        XCTAssertEqual(photo.textLineFrames, self.modelRow.textLineFrames)
    }

    func testRowShapesAreTheMockupsBarsOnTheMeasuredLines() {
        let shapes = newsSkeletonRowShapes(row: self.modelRow, index: 0, y: 0.0, width: 402.0, pixel: 1.0 / 3.0)
        XCTAssertEqual(shapes, [
            .circle(CGRect(x: 16.0, y: 11.0, width: 16.0, height: 16.0)),
            .roundedRect(CGRect(x: 36.0, y: 13.5, width: 130.0, height: 11.0), cornerRadius: 5.5),
            .roundedRect(CGRect(x: 174.0, y: 14.5, width: 24.0, height: 9.0), cornerRadius: 4.5),
            .roundedRect(CGRect(x: 16.0, y: 33.5, width: 370.0, height: 11.0), cornerRadius: 5.5),
            .roundedRect(CGRect(x: 16.0, y: 53.5, width: 344.0, height: 11.0), cornerRadius: 5.5),
            .roundedRect(CGRect(x: 16.0, y: 73.5, width: 207.0, height: 11.0), cornerRadius: 5.5),
            .separator(CGRect(x: 16.0, y: 96.0 - 1.0 / 3.0, width: 386.0, height: 1.0 / 3.0))
        ])
    }

    // The last line's length cycles per row: 0.56, 0.72, 0.44, 0.64, 0.50, 0.68, 0.38.
    func testLastLineTailCyclesPerRow() {
        let shapes = newsSkeletonRowShapes(row: self.modelRow, index: 1, y: 100.0, width: 402.0, pixel: 1.0 / 3.0)
        XCTAssertEqual(shapes[5], .roundedRect(CGRect(x: 16.0, y: 173.5, width: 266.0, height: 11.0), cornerRadius: 5.5))
    }

    func testSkeletonFillsTheHeight() {
        let shapes = newsSkeletonShapes(plain: self.modelRow, width: 402.0, height: 300.0, pixel: 1.0 / 3.0)
        let avatars = shapes.filter { if case .circle = $0 { return true } else { return false } }
        // Rows at y 0 (96), 96 (98), 194 (98), 292: four rows reach 300.
        XCTAssertEqual(avatars.count, 4)
        XCTAssertEqual(avatars.last, .circle(CGRect(x: 16.0, y: 303.0, width: 16.0, height: 16.0)))
        let thumbnails = shapes.filter { if case let .roundedRect(_, radius) = $0 { return radius == 10.0 } else { return false } }
        XCTAssertEqual(thumbnails.count, 2)
    }
}
