import Foundation

if CommandLine.arguments.count < 3 {
    print("Usage: SwiftTL path-to-scheme.tl path-to-swift-output-folder [--swift-file-count=N] [--objc-output=<dir>] [--fixtures-output=<path>] [--api-prefix=<prefix>]")
    exit(0)
}

let schemeFilePath = CommandLine.arguments[1]
let outputDirectoryPath = CommandLine.arguments[2]
var apiPrefix = "Api"
var objcOutputDirectoryPath: String?
var fixturesOutputPath: String?
var swiftFileCount = SwiftFileSplit.defaultFileCount

for arg in CommandLine.arguments[3...] {
    if arg.hasPrefix("--api-prefix=") {
        let value = String(arg.dropFirst("--api-prefix=".count))
        apiPrefix = value
    } else if arg.hasPrefix("--objc-output=") {
        objcOutputDirectoryPath = String(arg.dropFirst("--objc-output=".count))
    } else if arg.hasPrefix("--swift-file-count=") {
        guard let value = Int(arg.dropFirst("--swift-file-count=".count)) else {
            print("Error: --swift-file-count takes a number")
            exit(1)
        }
        swiftFileCount = value
    } else if arg.hasPrefix("--fixtures-output=") {
        fixturesOutputPath = String(arg.dropFirst("--fixtures-output=".count))
    } else {
        print("Error: Unknown argument: \(arg)")
        exit(1)
    }
}

guard let data = try? String(contentsOfFile: schemeFilePath) else {
    print("Could not open scheme file \(schemeFilePath)")
    exit(1)
}

do {
    let parsedSchema = try DescriptionParser.parse(data: data)

    try FileManager.default.createDirectory(at: URL(fileURLWithPath: outputDirectoryPath), withIntermediateDirectories: true, attributes: nil)

    switch parsedSchema {
    case let .flat(constructors, functions):
        let resolvedTypes = try Resolver.resolveTypes(constructors: constructors)
        var resolvedFunctions = try Resolver.resolveFunctions(types: resolvedTypes, functionDescriptions: functions)

        resolvedFunctions.append(Resolver.Function(name: QualifiedName(namespace: "help", value: "test"), id: 0xc0e202f7, arguments: [], result: .boxedType(QualifiedName(namespace: nil, value: "Bool"))))

        let typeOrder = try SwiftFileSplit.typeOrder(types: resolvedTypes, functions: resolvedFunctions, fileCount: swiftFileCount)
        let constructorOrder = typeOrder.flatMap { file in file.types.flatMap { type in type.constructorNames.map { (typeName: type.typeName, constructorName: $0) } } }

        guard let objcOutputDirectoryPath = objcOutputDirectoryPath else {
            print("Error: --objc-output=<dir> is required for the flat schema")
            exit(1)
        }
        let layout = try TLSchemaLayout.build(apiPrefix: apiPrefix, types: resolvedTypes, functions: resolvedFunctions)
        // FNV-1a over the schema text and the generator version, emitted into both the ObjC
        // schema table and the Swift output. tlVerifyClientLayout() inlines the Swift copy into
        // clients to catch one compiled against an older TelegramApi; the tests compare the two.
        var schemaHash: UInt64 = 0xcbf29ce484222325
        for byte in Array(data.utf8) + Array("SwiftTL-Storage/1".utf8) {
            schemaHash ^= UInt64(byte)
            schemaHash = schemaHash &* 0x100000001b3
        }

        let generatedFiles = try CodeGenerator.generate(apiPrefix: apiPrefix, types: resolvedTypes, functions: resolvedFunctions, constructorOrder: constructorOrder, typeOrder: typeOrder, layout: layout, schemaHash: schemaHash)

        for (name, fileData) in generatedFiles {
            let filePath = URL(fileURLWithPath: outputDirectoryPath).appendingPathComponent(name).path
            let _ = try? FileManager.default.removeItem(atPath: filePath)
            try fileData.write(toFile: filePath, atomically: true, encoding: .utf8)
        }

        if let fixturesOutputPath = fixturesOutputPath {
            let source = try FixtureGenerator.generate(apiPrefix: apiPrefix, types: resolvedTypes, functions: resolvedFunctions)
            let url = URL(fileURLWithPath: fixturesOutputPath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try source.write(to: url, atomically: true, encoding: .utf8)
            let probes = AccessorProbeGenerator.generate(apiPrefix: apiPrefix, layout: layout)
            try probes.write(to: url.deletingLastPathComponent().appendingPathComponent("SchemaAccessorProbes.swift"), atomically: true, encoding: .utf8)
        }

        let objcFiles = try ObjCCodeGenerator.generate(layout: layout, schemaHash: schemaHash)
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: objcOutputDirectoryPath), withIntermediateDirectories: true, attributes: nil)
        for (name, contents) in objcFiles {
            try contents.write(to: URL(fileURLWithPath: objcOutputDirectoryPath).appendingPathComponent(name), atomically: true, encoding: .utf8)
        }

    case let .layered(layers):
        let resolvedLayers = try Resolver.resolveLayeredTypes(layers: layers)
        for (layerNumber, types) in resolvedLayers {
            let (filename, source) = try CodeGenerator.generateLayered(apiPrefix: apiPrefix, layerNumber: layerNumber, types: types)
            let filePath = URL(fileURLWithPath: outputDirectoryPath).appendingPathComponent(filename).path
            let _ = try? FileManager.default.removeItem(atPath: filePath)
            try source.write(toFile: filePath, atomically: true, encoding: .utf8)
        }
    }
} catch let e {
    print("Error: \(e)")
    exit(1)
}
