import Foundation
import XCTest
@testable import Postbox

private struct Chunk: Codable, Equatable {
    var index: Int32
}

private struct ChunkKey: Codable, Hashable {
    var id: Int32
}

private struct Ints: Codable, Equatable { var values: [Int32] }
private struct Longs: Codable, Equatable { var values: [Int64] }
private struct Names: Codable, Equatable { var values: [String] }
private struct Blobs: Codable, Equatable { var values: [Data] }
private struct Table: Codable, Equatable { var values: [ChunkKey: Chunk] }

/// Every array kind the Codable adapter can store (`.Int32Array`, `.Int64Array`,
/// `.StringArray`, `.BytesArray`, `.ObjectDictionary`) goes through a raw reader that
/// takes its element count and lengths from the file. Corrupt values must fail the
/// decode, never read past the buffer.
final class AdaptedPostboxDecoderRawArrayTests: XCTestCase {
    private func encode<T: Encodable>(_ value: T) -> Data {
        let encoder = PostboxEncoder()
        encoder.encode(value, forKey: "v")
        return encoder.makeData()
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        return PostboxDecoder(buffer: MemoryBuffer(data: data)).decode(type, forKey: "v")
    }

    /// Offset of the first byte after `[len]["values"][type]`, i.e. the element count.
    private func countOffset(in data: Data) -> Int {
        guard let keyRange = data.range(of: "values".data(using: .utf8)!) else {
            XCTFail("key not found")
            return 0
        }
        return keyRange.upperBound + 1
    }

    private func patch(_ data: inout Data, at offset: Int, with value: Int32) {
        var value = value
        withUnsafeBytes(of: &value) { bytes in
            data.replaceSubrange(offset ..< offset + 4, with: bytes)
        }
    }

    // MARK: - Round trips (guards)

    func testEveryArrayKindRoundTrips() {
        XCTAssertEqual(self.decode(Ints.self, from: self.encode(Ints(values: [1, -2, 3]))), Ints(values: [1, -2, 3]))
        XCTAssertEqual(self.decode(Longs.self, from: self.encode(Longs(values: [1, -2, 1 << 40]))), Longs(values: [1, -2, 1 << 40]))
        XCTAssertEqual(self.decode(Names.self, from: self.encode(Names(values: ["a", "", "ccc"]))), Names(values: ["a", "", "ccc"]))
        XCTAssertEqual(self.decode(Blobs.self, from: self.encode(Blobs(values: [Data([1]), Data(), Data([2, 3])]))), Blobs(values: [Data([1]), Data(), Data([2, 3])]))
        let table = Table(values: [ChunkKey(id: 1): Chunk(index: 10), ChunkKey(id: 2): Chunk(index: 20)])
        XCTAssertEqual(self.decode(Table.self, from: self.encode(table)), table)
    }

    // MARK: - Corrupt counts

    func testInt32ArrayWithACountBeyondTheBufferFailsTheDecode() {
        var data = self.encode(Ints(values: [1, 2, 3]))
        self.patch(&data, at: self.countOffset(in: data), with: 0x7FFF_FFFF)

        XCTAssertNil(self.decode(Ints.self, from: data))
    }

    func testInt64ArrayWithACountBeyondTheBufferFailsTheDecode() {
        var data = self.encode(Longs(values: [1, 2, 3]))
        self.patch(&data, at: self.countOffset(in: data), with: 0x7FFF_FFFF)

        XCTAssertNil(self.decode(Longs.self, from: data))
    }

    func testInt32ArrayWithANegativeCountFailsTheDecode() {
        var data = self.encode(Ints(values: [1, 2, 3]))
        self.patch(&data, at: self.countOffset(in: data), with: -1)

        XCTAssertNil(self.decode(Ints.self, from: data))
    }

    // MARK: - Corrupt element lengths

    func testStringArrayWithAnElementLengthBeyondTheBufferFailsTheDecode() {
        var data = self.encode(Names(values: ["abc", "def"]))
        // First element length sits right after the count.
        self.patch(&data, at: self.countOffset(in: data) + 4, with: 0x7FFF_0000)

        XCTAssertNil(self.decode(Names.self, from: data))
    }

    func testBytesArrayWithAnElementLengthBeyondTheBufferFailsTheDecode() {
        var data = self.encode(Blobs(values: [Data([1, 2, 3]), Data([4])]))
        self.patch(&data, at: self.countOffset(in: data) + 4, with: 0x7FFF_0000)

        XCTAssertNil(self.decode(Blobs.self, from: data))
    }

    func testDictionaryWithAKeyLengthBeyondTheBufferFailsTheDecode() {
        var data = self.encode(Table(values: [ChunkKey(id: 1): Chunk(index: 10)]))
        // Layout after the count: [keyHash: 4][keyLength: 4] ...
        self.patch(&data, at: self.countOffset(in: data) + 4 + 4, with: 0x7FFF_0000)

        XCTAssertNil(self.decode(Table.self, from: data))
    }

    // MARK: - Direct per-key readers (no skip validation in front of them)

    /// Hand-builds `[keyLength][key][type]` followed by `payload`.
    private func value(forKey key: String, type: ValueType, payload: Data) -> MemoryBuffer {
        var data = Data()
        let keyData = key.data(using: .utf8)!
        data.append(UInt8(keyData.count))
        data.append(keyData)
        data.append(UInt8(bitPattern: type.rawValue))
        data.append(payload)
        return MemoryBuffer(data: data)
    }

    private func int32Payload(_ values: [Int32]) -> Data {
        var data = Data()
        for var value in values {
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        return data
    }

    func testInt32ArrayForKeyWithACountBeyondTheBufferReturnsEmpty() {
        let decoder = PostboxDecoder(buffer: self.value(forKey: "k", type: .Int32Array, payload: self.int32Payload([0x7FFF_FFFF, 1, 2])))

        XCTAssertEqual(decoder.decodeInt32ArrayForKey("k"), [])
    }

    func testInt64ArrayForKeyWithACountBeyondTheBufferReturnsEmpty() {
        let decoder = PostboxDecoder(buffer: self.value(forKey: "k", type: .Int64Array, payload: self.int32Payload([0x7FFF_FFFF, 0, 0])))

        XCTAssertEqual(decoder.decodeInt64ArrayForKey("k"), [])
    }

    func testStringArrayForKeyWithAnElementLengthBeyondTheBufferReturnsEmpty() {
        // count = 1, element length = 0x7FFF0000, then three bytes of text.
        var payload = self.int32Payload([1, 0x7FFF_0000])
        payload.append("abc".data(using: .utf8)!)
        let decoder = PostboxDecoder(buffer: self.value(forKey: "k", type: .StringArray, payload: payload))

        XCTAssertEqual(decoder.decodeStringArrayForKey("k"), [])
        XCTAssertNil(PostboxDecoder(buffer: self.value(forKey: "k", type: .StringArray, payload: payload)).decodeOptionalStringArrayForKey("k"))
    }

    func testBytesArrayForKeyWithAnElementLengthBeyondTheBufferReturnsEmpty() {
        var payload = self.int32Payload([1, 0x7FFF_0000])
        payload.append(Data([1, 2, 3]))
        let decoder = PostboxDecoder(buffer: self.value(forKey: "k", type: .BytesArray, payload: payload))

        XCTAssertTrue(decoder.decodeBytesArrayForKey("k").isEmpty)
    }

    func testInt32ArrayForKeyWithAValidPayloadStillReadsIt() {
        let decoder = PostboxDecoder(buffer: self.value(forKey: "k", type: .Int32Array, payload: self.int32Payload([3, 7, -8, 9])))

        XCTAssertEqual(decoder.decodeInt32ArrayForKey("k"), [7, -8, 9])
    }

    func testStringArrayWithAnElementLengthSlightlyPastTheValueFailsTheDecode() {
        var data = self.encode(Names(values: ["abcdef"]))
        // The array value is a handful of bytes; 256 overruns it while staying far
        // smaller than the whole buffer, so only a per-element bounds check catches it.
        self.patch(&data, at: self.countOffset(in: data) + 4, with: 256)

        XCTAssertNil(self.decode(Names.self, from: data))
    }
}
