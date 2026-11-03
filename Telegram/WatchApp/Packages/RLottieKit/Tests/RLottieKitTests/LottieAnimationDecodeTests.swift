import XCTest
@testable import RLottieKit
import CoreGraphics

final class LottieAnimationDecodeTests: XCTestCase {
    func testValidTgsLoads() throws {
        let url = Bundle.module.url(forResource: "tiny", withExtension: "tgs")!
        let animation = try XCTUnwrap(LottieAnimation(tgsFileURL: url))
        XCTAssertEqual(animation.dimensions, CGSize(width: 100, height: 100))
        XCTAssertEqual(animation.frameRate, 30)
        XCTAssertEqual(animation.frameCount, 30)
        XCTAssertEqual(animation.duration, 1.0, accuracy: 0.0001)
    }

    func testRandomBytesReturnsNil() throws {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("bogus-\(UUID().uuidString).tgs")
        let bogus = Data((0..<256).map { _ in UInt8.random(in: 0...255) })
        try bogus.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNil(LottieAnimation(tgsFileURL: url))
    }

    func testRawJsonReturnsNil() throws {
        // We accept TGS (gzipped) only — raw JSON should fail the gunzip step.
        let url = Bundle.module.url(forResource: "tiny", withExtension: "json")!
        XCTAssertNil(LottieAnimation(tgsFileURL: url))
    }

    func testRenderFrameProducesNonEmptyImage() throws {
        let url = Bundle.module.url(forResource: "tiny", withExtension: "tgs")!
        let animation = try XCTUnwrap(LottieAnimation(tgsFileURL: url))
        let image = animation.renderFrame(index: 0, size: CGSize(width: 32, height: 32), scale: 1.0)
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.width, 32)
        XCTAssertEqual(image?.height, 32)
    }
}
