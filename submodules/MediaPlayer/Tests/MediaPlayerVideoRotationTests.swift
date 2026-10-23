import CoreGraphics
import XCTest
@testable import UniversalMediaPlayer

final class MediaPlayerVideoRotationTests: XCTestCase {
    func testQuarterTurnsFillDisplayedBoundsWithoutStretching() {
        for encodedSize in [CGSize(width: 480.0, height: 272.0), CGSize(width: 272.0, height: 480.0)] {
            for angle in [Double.pi / 2.0, -Double.pi / 2.0, 3.0 * Double.pi / 2.0] {
                for scale in [0.5, 1.0, 2.0] as [CGFloat] {
                    let displayedSize = CGSize(width: encodedSize.height * scale, height: encodedSize.width * scale)
                    let transform = mediaPlayerVideoRotationTransform(size: displayedSize, rotationAngle: angle)
                    let centeredBounds = CGRect(x: -displayedSize.width / 2.0, y: -displayedSize.height / 2.0, width: displayedSize.width, height: displayedSize.height)
                    let transformedBounds = centeredBounds.applying(transform)
                    XCTAssertEqual(transformedBounds.width, displayedSize.width, accuracy: 0.00001)
                    XCTAssertEqual(transformedBounds.height, displayedSize.height, accuracy: 0.00001)
                    XCTAssertEqual(transformedBounds.midX, 0.0, accuracy: 0.00001)
                    XCTAssertEqual(transformedBounds.midY, 0.0, accuracy: 0.00001)

                    // .resize first maps the encoded raster into the displayed bounds.
                    // The final transform must give both encoded pixel axes the same scale.
                    let xScale = displayedSize.width / encodedSize.width * hypot(transform.a, transform.b)
                    let yScale = displayedSize.height / encodedSize.height * hypot(transform.c, transform.d)
                    XCTAssertEqual(xScale, scale, accuracy: 0.00001)
                    XCTAssertEqual(yScale, scale, accuracy: 0.00001)
                }
            }
        }
    }

    func testRotationDirection() {
        let size = CGSize(width: 272.0, height: 480.0)
        // FFMpegBinding negates av_display_rotation_get: a -90 degree MP4
        // matrix becomes +pi/2 in UIKit coordinates (the right edge goes down).
        let clockwise = mediaPlayerVideoRotationTransform(size: size, rotationAngle: Double.pi / 2.0)
        let counterclockwise = mediaPlayerVideoRotationTransform(size: size, rotationAngle: -Double.pi / 2.0)
        XCTAssertGreaterThan(CGPoint(x: 1.0, y: 0.0).applying(clockwise).y, 0.0)
        XCTAssertLessThan(CGPoint(x: 1.0, y: 0.0).applying(counterclockwise).y, 0.0)
    }

    func testZeroAndHalfTurnsDoNotSwapAxes() {
        for size in [CGSize(width: 480.0, height: 272.0), CGSize(width: 272.0, height: 480.0)] {
            XCTAssertEqual(mediaPlayerVideoRotationTransform(size: size, rotationAngle: 0.0), .identity)
            for angle in [Double.pi, -Double.pi] {
                let transform = mediaPlayerVideoRotationTransform(size: size, rotationAngle: angle)
                XCTAssertEqual(hypot(transform.a, transform.b), 1.0, accuracy: 0.00001)
                XCTAssertEqual(hypot(transform.c, transform.d), 1.0, accuracy: 0.00001)
            }
        }
    }

    func testInvalidGeometryDoesNotProduceInvalidLayerTransform() {
        XCTAssertEqual(mediaPlayerVideoRotationTransform(size: .zero, rotationAngle: Double.pi / 2.0), .identity)
        XCTAssertEqual(mediaPlayerVideoRotationTransform(size: CGSize(width: 272.0, height: 480.0), rotationAngle: .nan), .identity)
    }
}
