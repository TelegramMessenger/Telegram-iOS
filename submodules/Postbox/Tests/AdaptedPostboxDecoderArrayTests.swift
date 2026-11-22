import Foundation
import XCTest
@testable import Postbox

private struct Chunk: Codable, Equatable {
    var index: Int32
    var payload: Data
}

private struct Container: Codable, Equatable {
    var chunks: [Chunk]
}

/// Arrays of Codable objects travel through `PostboxDecoder.decodeObjectDataArrayRaw`.
/// Its only job is to split the array bytes into elements; it must accept any element
/// that fits inside the buffer, and reject corruption by failing the decode rather than
/// returning a partial array.
final class AdaptedPostboxDecoderArrayTests: XCTestCase {
    private func encode(_ container: Container) -> Data {
        let encoder = PostboxEncoder()
        encoder.encode(container, forKey: "c")
        return encoder.makeData()
    }

    private func decode(_ data: Data) -> Container? {
        return PostboxDecoder(buffer: MemoryBuffer(data: data)).decode(Container.self, forKey: "c")
    }

    func testArrayWithAnElementLargerThanTwoMebibytesRoundTrips() {
        let large = Data(repeating: 0xAB, count: 3 * 1024 * 1024)
        let container = Container(chunks: [
            Chunk(index: 1, payload: Data([1, 2, 3])),
            Chunk(index: 2, payload: large),
            Chunk(index: 3, payload: Data([4, 5])),
        ])

        let decoded = self.decode(self.encode(container))

        XCTAssertEqual(decoded?.chunks.count, 3)
        XCTAssertEqual(decoded, container)
    }

    func testElementLengthPointingPastTheBufferFailsTheWholeDecode() {
        let container = Container(chunks: [
            Chunk(index: 1, payload: Data([1, 2, 3])),
            Chunk(index: 2, payload: Data([4, 5, 6])),
        ])
        var data = self.encode(container)
        XCTAssertEqual(self.decode(data), container, "fixture must decode before it is corrupted")

        // Layout after the "chunks" key: [type: 1][count: 4][typeHash: 4][objectLength: 4] ...
        guard let keyRange = data.range(of: "chunks".data(using: .utf8)!) else {
            return XCTFail("key not found in encoded data")
        }
        let objectLengthOffset = keyRange.upperBound + 1 + 4 + 4
        var corruptLength: Int32 = 0x7FFF_0000
        withUnsafeBytes(of: &corruptLength) { bytes in
            data.replaceSubrange(objectLengthOffset ..< objectLengthOffset + 4, with: bytes)
        }

        XCTAssertNil(self.decode(data))
    }

    func testNegativeElementLengthFailsTheWholeDecode() {
        let container = Container(chunks: [Chunk(index: 1, payload: Data([1]))])
        var data = self.encode(container)

        guard let keyRange = data.range(of: "chunks".data(using: .utf8)!) else {
            return XCTFail("key not found in encoded data")
        }
        let objectLengthOffset = keyRange.upperBound + 1 + 4 + 4
        var corruptLength: Int32 = -1
        withUnsafeBytes(of: &corruptLength) { bytes in
            data.replaceSubrange(objectLengthOffset ..< objectLengthOffset + 4, with: bytes)
        }

        XCTAssertNil(self.decode(data))
    }
}
