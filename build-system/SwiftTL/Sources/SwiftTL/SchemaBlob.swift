import Foundation
import zlib

/// The schema table as one pointer-free little-endian image, zlib-compressed into
/// TLApiSchemaData.m and rebuilt into the runtime structs by TLSchemaLoader.m on first use.
///
/// Image (version 3). Sections follow each other in this order; every reference is an index or
/// a byte offset, never a pointer:
/// - header, 72 bytes: magic `TLS1`, version, schema hash (u64), image length, then the counts
///   of types, constructors, functions, field records and type-constructor entries, the string
///   pool's offset and length, the offsets of the types, type-constructor, constructor, field
///   and function sections, and a zero word.
/// - types, 12 bytes each, in schema order: name (pool offset), first type-constructor entry,
///   constructor count.
/// - type-constructor entries, u32 each: indices into the constructor section, in case order.
/// - constructors, 28 bytes each, ascending unsigned id: name, id, type index, case index (u16
///   each), first field record, field count (u16) + pad (u16), instance size, presence-mask
///   offset (i32, -1 without optional scalars).
/// - field records, 20 bytes each, shared by constructors and functions: name, kind, element
///   kind, optional, boxed vector, bare object (u8 each), flags field index (i8, -1 if none),
///   flag bit, presence bit (u8 each), object type index, bare constructor index (u16 each),
///   storage offset (u32).
/// - functions, 28 bytes each, in schema order: name, id, first field record, field count (u16)
///   + pad (u16), the result's field record, instance size, presence-mask offset; followed in
///   the field section by the parameter records and then the result record.
/// - string pool: NUL-terminated UTF-8. Only this section is kept after decoding.
enum SchemaBlob {
    static let magic: UInt32 = 0x31534C54   // "TLS1"
    static let version: UInt32 = 3
    static let headerSize = 72

    struct EncodingError: Error, CustomStringConvertible {
        var description: String
    }

    private struct Writer {
        var bytes: [UInt8] = []

        mutating func u8(_ value: UInt8) {
            bytes.append(value)
        }

        mutating func i8(_ value: Int8) {
            bytes.append(UInt8(bitPattern: value))
        }

        mutating func u16(_ value: UInt16) {
            withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
        }

        mutating func u32(_ value: UInt32) {
            withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
        }

        mutating func u64(_ value: UInt64) {
            withUnsafeBytes(of: value.littleEndian) { bytes.append(contentsOf: $0) }
        }
    }

    private struct StringPool {
        var bytes: [UInt8] = []
        var offsets: [String: UInt32] = [:]

        mutating func offset(_ string: String) -> UInt32 {
            if let existing = offsets[string] {
                return existing
            }
            let offset = UInt32(bytes.count)
            bytes.append(contentsOf: Array(string.utf8))
            bytes.append(0)
            offsets[string] = offset
            return offset
        }
    }

    private static func kindValue(_ kind: TLKind) -> UInt8 {
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

    /// `TLApiConstructorAt(i)` order: ascending unsigned constructor id.
    static func constructorsById(_ layout: TLSchemaLayout) -> [TLConstructorLayout] {
        return layout.types.flatMap(\.constructors).sorted(by: { $0.constructor.id < $1.constructor.id })
    }

    static func encodeImage(layout: TLSchemaLayout, schemaHash: UInt64) throws -> [UInt8] {
        var pool = StringPool()
        let byId = constructorsById(layout)
        var byIdIndex: [UInt32: Int] = [:]
        for (index, constructor) in byId.enumerated() {
            guard byIdIndex.updateValue(index, forKey: constructor.constructor.id) == nil else {
                throw EncodingError(description: "duplicate constructor id \(constructor.constructor.id)")
            }
        }

        var fields = Writer()
        var fieldCount = 0
        func writeField(_ field: TLFieldLayout) {
            fields.u32(pool.offset(field.descriptionName))
            fields.u8(kindValue(field.kind))
            fields.u8(field.elementKind.map(kindValue) ?? 0)
            fields.u8(field.isOptional ? 1 : 0)
            fields.u8(field.isBoxedVector ? 1 : 0)
            fields.u8(field.bareConstructorIndex != nil ? 1 : 0)
            fields.i8(Int8(field.flagsFieldIndex ?? -1))
            fields.u8(field.flagsFieldIndex != nil ? UInt8(field.flagBit) : 0)
            fields.u8(UInt8(field.presenceBit ?? 0))
            fields.u16(UInt16(field.objectType.map { layout.typeLayout(for: $0).typeIndex } ?? 0))
            fields.u16(UInt16(field.bareConstructorIndex ?? 0))
            fields.u32(UInt32(field.offset))
            fieldCount += 1
        }

        var types = Writer()
        var typeConstructors = Writer()
        var typeConstructorCount = 0
        for type in layout.types {
            types.u32(pool.offset(type.type.name.description))
            types.u32(UInt32(typeConstructorCount))
            types.u32(UInt32(type.constructors.count))
            for constructor in type.constructors {
                typeConstructors.u32(UInt32(byIdIndex[constructor.constructor.id]!))
                typeConstructorCount += 1
            }
        }

        var constructors = Writer()
        for constructor in byId {
            constructors.u32(pool.offset(constructor.constructor.name.value))
            constructors.u32(constructor.constructor.id)
            constructors.u16(UInt16(constructor.typeIndex))
            constructors.u16(UInt16(constructor.caseIndex))
            constructors.u32(UInt32(fieldCount))
            constructors.u16(UInt16(constructor.fields.count))
            constructors.u16(0)
            constructors.u32(UInt32(constructor.instanceSize))
            constructors.u32(UInt32(bitPattern: Int32(constructor.presentOffset)))
            for field in constructor.fields {
                writeField(field)
            }
        }

        var functions = Writer()
        for function in layout.functions {
            functions.u32(pool.offset("\(function.function.name)"))
            functions.u32(function.function.id)
            functions.u32(UInt32(fieldCount))
            functions.u16(UInt16(function.fields.count))
            functions.u16(0)
            for field in function.fields {
                writeField(field)
            }
            functions.u32(UInt32(fieldCount))
            functions.u32(UInt32(function.instanceSize))
            functions.u32(UInt32(bitPattern: Int32(function.presentOffset)))
            writeField(function.result)
        }

        let typesOffset = headerSize
        let typeConstructorsOffset = typesOffset + types.bytes.count
        let constructorsOffset = typeConstructorsOffset + typeConstructors.bytes.count
        let fieldsOffset = constructorsOffset + constructors.bytes.count
        let functionsOffset = fieldsOffset + fields.bytes.count
        let poolOffset = functionsOffset + functions.bytes.count
        let imageLength = poolOffset + pool.bytes.count

        var header = Writer()
        header.u32(magic)
        header.u32(version)
        header.u64(schemaHash)
        header.u32(UInt32(imageLength))
        header.u32(UInt32(layout.types.count))
        header.u32(UInt32(byId.count))
        header.u32(UInt32(layout.functions.count))
        header.u32(UInt32(fieldCount))
        header.u32(UInt32(typeConstructorCount))
        header.u32(UInt32(poolOffset))
        header.u32(UInt32(pool.bytes.count))
        header.u32(UInt32(typesOffset))
        header.u32(UInt32(typeConstructorsOffset))
        header.u32(UInt32(constructorsOffset))
        header.u32(UInt32(fieldsOffset))
        header.u32(UInt32(functionsOffset))
        header.u32(0)
        precondition(header.bytes.count == headerSize)

        return header.bytes + types.bytes + typeConstructors.bytes + constructors.bytes + fields.bytes + functions.bytes + pool.bytes
    }

    static func compress(_ image: [UInt8]) throws -> [UInt8] {
        var output = [UInt8](repeating: 0, count: Int(compressBound(uLong(image.count))))
        var length = uLongf(output.count)
        let status = compress2(&output, &length, image, uLong(image.count), 9)
        guard status == Z_OK else {
            throw EncodingError(description: "compress2 failed: \(status)")
        }
        return Array(output.prefix(Int(length)))
    }

    static func source(compressed: [UInt8], classPrefix: String) -> String {
        var out = "// Generated by SwiftTL. Do not edit.\n#import <TelegramApiObjC/TelegramApiObjC.h>\n\n"
        out += "// The schema table, zlib-compressed. Decoded on first use by TLSchemaLoader.m.\n"
        out += "const uint8_t \(classPrefix)SchemaCompressed[] = {\n"
        for start in stride(from: 0, to: compressed.count, by: 16) {
            let line = compressed[start ..< min(start + 16, compressed.count)].map { String(format: "0x%02x,", Int($0)) }
            out += "    " + line.joined(separator: " ") + "\n"
        }
        out += "};\nconst uint32_t \(classPrefix)SchemaCompressedLength = \(compressed.count);\n"
        return out
    }
}
