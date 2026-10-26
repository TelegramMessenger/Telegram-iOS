import Foundation
import XCTest
import zlib
@testable import SwiftTL

/// A test-only reader of the image format documented in SchemaBlob.swift.
private struct ImageReader {
    let bytes: [UInt8]

    func u8(_ offset: Int) -> UInt8 { return bytes[offset] }
    func u16(_ offset: Int) -> UInt16 { return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8 }
    func u32(_ offset: Int) -> UInt32 { return (0 ..< 4).reduce(UInt32(0)) { $0 | UInt32(bytes[offset + $1]) << (8 * UInt32($1)) } }
    func u64(_ offset: Int) -> UInt64 { return (0 ..< 8).reduce(UInt64(0)) { $0 | UInt64(bytes[offset + $1]) << (8 * UInt64($1)) } }

    var poolOffset: Int { return Int(u32(40)) }

    func string(_ offset: UInt32) -> String {
        let start = poolOffset + Int(offset)
        var end = start
        while bytes[end] != 0 { end += 1 }
        return String(decoding: bytes[start ..< end], as: UTF8.self)
    }

    struct Field: Equatable {
        var name: String, kind: UInt8, elementKind: UInt8, isOptional: UInt8, isBoxedVector: UInt8
        var isBareObject: UInt8, flagsFieldIndex: Int8, flagBit: UInt8, presenceBit: UInt8, typeIndex: UInt16, constructorIndex: UInt16, offset: UInt32
    }

    func field(_ index: Int) -> Field {
        let o = Int(u32(60)) + index * 20
        return Field(name: string(u32(o)), kind: u8(o + 4), elementKind: u8(o + 5),
                     isOptional: u8(o + 6), isBoxedVector: u8(o + 7), isBareObject: u8(o + 8),
                     flagsFieldIndex: Int8(bitPattern: u8(o + 9)), flagBit: u8(o + 10), presenceBit: u8(o + 11),
                     typeIndex: u16(o + 12), constructorIndex: u16(o + 14), offset: u32(o + 16))
    }
}

private func kindValue(_ kind: TLKind) -> UInt8 {
    switch kind {
    case .int32: return 0
    case .int64: return 1
    case .int256: return 2
    case .double: return 3
    case .string: return 4
    case .bytes: return 5
    case .object: return 6
    case .vector: return 7
    }
}

private func expectedField(_ field: TLFieldLayout, layout: TLSchemaLayout) -> ImageReader.Field {
    return ImageReader.Field(
        name: field.descriptionName, kind: kindValue(field.kind),
        elementKind: field.elementKind.map(kindValue) ?? 0, isOptional: field.isOptional ? 1 : 0,
        isBoxedVector: field.isBoxedVector ? 1 : 0, isBareObject: field.bareConstructorIndex != nil ? 1 : 0,
        flagsFieldIndex: Int8(field.flagsFieldIndex ?? -1), flagBit: field.flagsFieldIndex != nil ? UInt8(field.flagBit) : 0,
        presenceBit: UInt8(field.presenceBit ?? 0),
        typeIndex: UInt16(field.objectType.map { layout.typeLayout(for: $0).typeIndex } ?? 0),
        constructorIndex: UInt16(field.bareConstructorIndex ?? 0), offset: UInt32(field.offset))
}

final class SchemaBlobTests: XCTestCase {
    func testHeaderDescribesTheImage() throws {
        let layout = try layoutForTestSchema()
        let image = try SchemaBlob.encodeImage(layout: layout, schemaHash: 0x1122334455667788)
        let r = ImageReader(bytes: image)
        XCTAssertEqual(Array(image[0 ..< 4]), Array("TLS1".utf8))
        XCTAssertEqual(r.u32(4), 3)
        XCTAssertEqual(r.u64(8), 0x1122334455667788)
        XCTAssertEqual(Int(r.u32(16)), image.count)
        XCTAssertEqual(r.u32(20), 7)
        XCTAssertEqual(r.u32(24), 9)
        XCTAssertEqual(r.u32(28), 2)
        let expectedFields = layout.types.flatMap(\.constructors).map(\.fields.count).reduce(0, +)
            + layout.functions.map { $0.fields.count + 1 }.reduce(0, +)
        XCTAssertEqual(Int(r.u32(32)), expectedFields)
        XCTAssertEqual(Int(r.u32(36)), 9)
        XCTAssertEqual(r.u32(48), 72)
        XCTAssertEqual(r.u32(68), 0)
        XCTAssertEqual(Int(r.u32(40) + r.u32(44)), image.count)
        XCTAssertEqual(image.last, 0)
    }

    func testEveryRecordRoundTrips() throws {
        let layout = try layoutForTestSchema()
        let r = ImageReader(bytes: try SchemaBlob.encodeImage(layout: layout, schemaHash: 1))
        let byId = SchemaBlob.constructorsById(layout)
        XCTAssertEqual(byId.map(\.constructor.id), byId.map(\.constructor.id).sorted())

        for (index, constructor) in byId.enumerated() {
            let o = Int(r.u32(56)) + index * 28
            XCTAssertEqual(r.string(r.u32(o)), constructor.constructor.name.value)
            XCTAssertEqual(r.u32(o + 4), constructor.constructor.id)
            XCTAssertEqual(Int(r.u16(o + 8)), constructor.typeIndex)
            XCTAssertEqual(Int(r.u16(o + 10)), constructor.caseIndex)
            XCTAssertEqual(Int(r.u16(o + 16)), constructor.fields.count)
            XCTAssertEqual(Int(r.u32(o + 20)), constructor.instanceSize)
            XCTAssertEqual(Int(Int32(bitPattern: r.u32(o + 24))), constructor.presentOffset)
            let first = Int(r.u32(o + 12))
            for (k, field) in constructor.fields.enumerated() {
                XCTAssertEqual(r.field(first + k), expectedField(field, layout: layout), "\(constructor.objcClassName).\(field.swiftName)")
            }
        }

        for (typeIndex, type) in layout.types.enumerated() {
            let o = 72 + typeIndex * 12
            XCTAssertEqual(r.string(r.u32(o)), type.type.name.description)
            XCTAssertEqual(Int(r.u32(o + 8)), type.constructors.count)
            let first = Int(r.u32(o + 4))
            for (caseIndex, constructor) in type.constructors.enumerated() {
                let byIdIndex = Int(r.u32(Int(r.u32(52)) + (first + caseIndex) * 4))
                XCTAssertEqual(byId[byIdIndex].objcClassName, constructor.objcClassName)
            }
        }

        for (index, function) in layout.functions.enumerated() {
            let o = Int(r.u32(64)) + index * 28
            XCTAssertEqual(r.string(r.u32(o)), "\(function.function.name)")
            XCTAssertEqual(r.u32(o + 4), function.function.id)
            XCTAssertEqual(Int(r.u16(o + 12)), function.fields.count)
            let first = Int(r.u32(o + 8))
            for (k, field) in function.fields.enumerated() {
                XCTAssertEqual(r.field(first + k), expectedField(field, layout: layout), "\(function.objcClassName).\(field.swiftName)")
            }
            XCTAssertEqual(r.field(Int(r.u32(o + 16))), expectedField(function.result, layout: layout))
            XCTAssertEqual(Int(r.u32(o + 20)), function.instanceSize)
            XCTAssertEqual(Int(Int32(bitPattern: r.u32(o + 24))), function.presentOffset)
        }
    }

    func testBareConstructorFieldIsMarked() throws {
        let layout = try layoutForTestSchema()
        let r = ImageReader(bytes: try SchemaBlob.encodeImage(layout: layout, schemaHash: 1))
        let byId = SchemaBlob.constructorsById(layout)
        let index = byId.firstIndex { $0.objcClassName == "TLApi_BotCommands_botCommands" }!
        let first = Int(r.u32(Int(r.u32(56)) + index * 28 + 12))
        let field = r.field(first)
        XCTAssertEqual(field.name, "first")
        XCTAssertEqual(field.kind, 6)
        XCTAssertEqual(field.isBareObject, 1)
        XCTAssertEqual(field.typeIndex, 1)
        XCTAssertEqual(field.constructorIndex, 0)
    }

    func testCompressionIsDeterministicAndLossless() throws {
        let image = try SchemaBlob.encodeImage(layout: try layoutForTestSchema(), schemaHash: 1)
        XCTAssertEqual(try SchemaBlob.encodeImage(layout: try layoutForTestSchema(), schemaHash: 1), image)
        let compressed = try SchemaBlob.compress(image)
        XCTAssertEqual(try SchemaBlob.compress(image), compressed)
        XCTAssertEqual(compressed.first, 0x78)
        var output = [UInt8](repeating: 0, count: image.count)
        var length = uLongf(output.count)
        XCTAssertEqual(uncompress(&output, &length, compressed, uLong(compressed.count)), Z_OK)
        XCTAssertEqual(Array(output.prefix(Int(length))), image)
    }

    func testEmittedSourceCarriesTheCompressedBytes() throws {
        let layout = try layoutForTestSchema()
        let files = try ObjCCodeGenerator.generate(layout: layout, schemaHash: 0x1234)
        let source = try XCTUnwrap(files["TLApiSchemaData.m"])
        let expected = try SchemaBlob.compress(try SchemaBlob.encodeImage(layout: layout, schemaHash: 0x1234))
        let bytes = source.components(separatedBy: CharacterSet(charactersIn: " ,\n")).filter { $0.hasPrefix("0x") && $0.count == 4 }.map { UInt8($0.dropFirst(2), radix: 16)! }
        XCTAssertEqual(bytes, expected)
        XCTAssertTrue(source.contains("const uint32_t TLApiSchemaCompressedLength = \(expected.count);"))
        XCTAssertTrue(source.contains("const uint8_t TLApiSchemaCompressed[] = {"))
    }
}
