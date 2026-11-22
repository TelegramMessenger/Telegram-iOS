import Foundation
import XCTest
import zlib
import TelegramApiObjC
@testable import TelegramApi

private func appImage() -> [UInt8] {
    var image: UnsafeMutablePointer<UInt8>?
    var length = 0
    let result = TLSchemaInflate(TLApiSchemaCompressedBytes(), TLApiSchemaCompressedByteCount(), &image, &length)
    precondition(result == .ok)
    defer { free(image) }
    return Array(UnsafeBufferPointer(start: image, count: length))
}

private func decode(_ image: [UInt8]) -> TLSchemaDecodeResult {
    var table = TLSchemaTable()
    let result = image.withUnsafeBufferPointer { TLSchemaDecodeImage($0.baseAddress!, $0.count, &table) }
    TLSchemaTableFree(&table)
    return result
}

private func decodeCompressed(_ compressed: [UInt8]) -> TLSchemaDecodeResult {
    var table = TLSchemaTable()
    let result = compressed.withUnsafeBufferPointer { TLSchemaDecode($0.baseAddress!, $0.count, &table) }
    TLSchemaTableFree(&table)
    return result
}

private func u32(_ image: [UInt8], _ offset: Int) -> UInt32 {
    return (0 ..< 4).reduce(UInt32(0)) { $0 | UInt32(image[offset + $1]) << (8 * UInt32($1)) }
}

private func setU32(_ image: inout [UInt8], _ offset: Int, _ value: UInt32) {
    for i in 0 ..< 4 {
        image[offset + i] = UInt8(truncatingIfNeeded: value >> (8 * UInt32(i)))
    }
}

private func compressedAppBlob() -> [UInt8] {
    return Array(UnsafeBufferPointer(start: TLApiSchemaCompressedBytes(), count: TLApiSchemaCompressedByteCount()))
}

final class SchemaImageTests: XCTestCase {
    func testAppImageDecodes() {
        XCTAssertEqual(decode(appImage()), .ok)
    }

    func testCorruptInputIsReportedNotTrapped() {
        let image = appImage()
        let compressed = compressedAppBlob()

        XCTAssertEqual(decodeCompressed(Array(compressed.prefix(compressed.count / 2))), .inflateFailed)
        var flipped = compressed
        flipped[compressed.count / 2] ^= 0x5a
        XCTAssertEqual(decodeCompressed(flipped), .inflateFailed)

        XCTAssertEqual(decode(Array(image.prefix(40))), .truncated)
        var badMagic = image
        badMagic[0] ^= 1
        XCTAssertEqual(decode(badMagic), .badMagic)
        var badVersion = image
        setU32(&badVersion, 4, 99)
        XCTAssertEqual(decode(badVersion), .badVersion)
        XCTAssertEqual(decode(Array(image.dropLast())), .lengthMismatch)

        let poolLength = u32(image, 44)
        let constructorsOffset = Int(u32(image, 56))
        var badName = image
        setU32(&badName, constructorsOffset, poolLength)
        XCTAssertEqual(decode(badName), .stringOutOfRange)
        var unterminated = image
        unterminated[unterminated.count - 1] = 0x41
        XCTAssertEqual(decode(unterminated), .stringOutOfRange)

        var badTypeRange = image
        setU32(&badTypeRange, 72 + 4, u32(image, 36))
        XCTAssertEqual(decode(badTypeRange), .invalidRecord)
        var badKind = image
        badKind[Int(u32(image, 60)) + 4] = 9
        XCTAssertEqual(decode(badKind), .invalidRecord)
        var wrongOwner = image
        let firstTypeConstructor = Int(u32(image, 52))
        setU32(&wrongOwner, firstTypeConstructor, u32(image, firstTypeConstructor) == 0 ? 1 : 0)
        XCTAssertEqual(decode(wrongOwner), .invalidRecord)

        var badSize = image
        setU32(&badSize, constructorsOffset + 20, 8)
        XCTAssertEqual(decode(badSize), .invalidRecord)

        var unsorted = image
        let firstId = u32(image, constructorsOffset + 4)
        setU32(&unsorted, constructorsOffset + 4, u32(image, constructorsOffset + 28 + 4))
        setU32(&unsorted, constructorsOffset + 28 + 4, firstId)
        XCTAssertEqual(decode(unsorted), .notSorted)
    }

    func testInflateRefusesAnOversizedStream() {
        let zeros = [UInt8](repeating: 0, count: Int(TLSchemaMaxImageLength) + 1)
        var compressed = [UInt8](repeating: 0, count: Int(compressBound(uLong(zeros.count))))
        var length = uLongf(compressed.count)
        XCTAssertEqual(compress2(&compressed, &length, zeros, uLong(zeros.count), 9), Z_OK)
        var image: UnsafeMutablePointer<UInt8>?
        var imageLength = 0
        XCTAssertEqual(TLSchemaInflate(compressed, Int(length), &image, &imageLength), .inflateFailed)
        XCTAssertNil(image)
    }

    /// Only the string pool outlives the decode: the record sections are read once into the
    /// structs, so keeping the whole image would waste its record bytes for the process lifetime.
    func testTableKeepsOnlyTheStringPool() {
        let image = appImage()
        var table = TLSchemaTable()
        XCTAssertEqual(image.withUnsafeBufferPointer { TLSchemaDecodeImage($0.baseAddress!, $0.count, &table) }, .ok)
        XCTAssertEqual(table.poolLength, Int(u32(image, 44)))
        XCTAssertEqual(String(cString: table.constructors![0].name), String(cString: TLApiConstructorAt(0).pointee.name))
        TLSchemaTableFree(&table)
    }

    func testTableIsDecodedOnceUnderConcurrentFirstUse() {
        let lock = NSLock()
        var seen = Set<UnsafeRawPointer>()
        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            let table = UnsafeRawPointer(TLApiSchemaTable())
            lock.lock()
            seen.insert(table)
            lock.unlock()
        }
        XCTAssertEqual(seen.count, 1)
        XCTAssertEqual(TLApiSchemaLoadCount(), 1)
    }

    /// Prints the first-use decode cost: median time, heap, string-pool and compressed bytes.
    func testReportLoadCost() {
        var times: [Double] = []
        var heapBytes = 0
        var imageBytes = 0
        for _ in 0 ..< 21 {
            var table = TLSchemaTable()
            let start = DispatchTime.now().uptimeNanoseconds
            XCTAssertEqual(TLSchemaDecode(TLApiSchemaCompressedBytes(), TLApiSchemaCompressedByteCount(), &table), .ok)
            times.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
            heapBytes = table.heapBytes
            imageBytes = table.poolLength
            TLSchemaTableFree(&table)
        }
        let median = times.sorted()[times.count / 2]
        print("TLSCHEMA_COST decodeMs=\(String(format: "%.3f", median)) heapBytes=\(heapBytes) poolBytes=\(imageBytes) compressedBytes=\(TLApiSchemaCompressedByteCount())")
        XCTAssertGreaterThan(heapBytes, imageBytes)
    }
}
