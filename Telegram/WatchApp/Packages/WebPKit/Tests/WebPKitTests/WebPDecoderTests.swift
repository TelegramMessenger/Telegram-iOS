import XCTest
import CoreGraphics
@testable import WebPKit

final class WebPDecoderTests: XCTestCase {
    func testDecodesRealTelegramWebp() throws {
        let url = Bundle.module.url(forResource: "sticker_raster", withExtension: "webp")!
        let cgImage = WebPDecoder.decode(url: url)
        let img = try XCTUnwrap(cgImage)
        XCTAssertEqual(img.width, 512)
        XCTAssertEqual(img.height, 401)
    }

    func testDecodesFromData() throws {
        let url = Bundle.module.url(forResource: "sticker_raster", withExtension: "webp")!
        let data = try Data(contentsOf: url)
        let img = WebPDecoder.decode(data: data)
        XCTAssertNotNil(img)
    }

    func testRandomBytesReturnsNil() {
        let bogus = Data((0..<256).map { _ in UInt8.random(in: 0...255) })
        XCTAssertNil(WebPDecoder.decode(data: bogus))
    }

    func testEmptyDataReturnsNil() {
        XCTAssertNil(WebPDecoder.decode(data: Data()))
    }
}
