import XCTest
@testable import RLottieKit

final class TgsDecompressTests: XCTestCase {
    func testGzippedTgsRoundtripsToOriginalJson() throws {
        let tgsURL = Bundle.module.url(forResource: "tiny", withExtension: "tgs")!
        let jsonURL = Bundle.module.url(forResource: "tiny", withExtension: "json")!
        let tgsData = try Data(contentsOf: tgsURL)
        let expectedJson = try Data(contentsOf: jsonURL)

        let decompressed = try decompressTgs(tgsData)

        XCTAssertEqual(decompressed, expectedJson)
    }

    func testRandomBytesThrows() {
        let randomBytes = Data((0..<256).map { _ in UInt8.random(in: 0...255) })
        XCTAssertThrowsError(try decompressTgs(randomBytes))
    }

    func testEmptyDataThrows() {
        XCTAssertThrowsError(try decompressTgs(Data()))
    }
}
