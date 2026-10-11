import Foundation

/// The generated half of the ObjC module: the compressed schema table, with its counts and hash.
/// Only this source is generated; its declarations live in the static
/// TLApiTypes.h, because a generated public header would sit on both Bazel's and SwiftPM's include
/// paths. Payloads are Swift structs over `TLObject` storage (see CodeGeneration.swift), so no
/// classes are generated.
enum ObjCCodeGenerator {
    static func generate(layout: TLSchemaLayout, schemaHash: UInt64) throws -> [String: String] {
        let p = layout.classPrefix
        let compressed = try SchemaBlob.compress(try SchemaBlob.encodeImage(layout: layout, schemaHash: schemaHash))
        var source = SchemaBlob.source(compressed: compressed, classPrefix: p)
        // TelegramApi's tests compare these with the generated Swift (SchemaTableTests).
        source += "\n"
        source += "const uint32_t \(p)TypeCount = \(layout.types.count);\n"
        source += "const uint32_t \(p)ConstructorCount = \(layout.types.flatMap(\.constructors).count);\n"
        source += "const uint32_t \(p)FunctionCount = \(layout.functions.count);\n"
        source += "const uint64_t \(p)SchemaHash = 0x\(String(schemaHash, radix: 16))ull;\n"
        return ["\(p)SchemaData.m": source]
    }
}
