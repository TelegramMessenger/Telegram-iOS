import Foundation
import XCTest
@testable import SwiftTL

private let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
private let runtimeHeader = repoRoot.appendingPathComponent("submodules/TelegramApi/ObjC/PublicHeaders/TelegramApiObjC/TLObject.h")

private func runTool(_ arguments: [String]) throws -> (Int32, String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    process.waitUntilExit()
    return (process.terminationStatus, output)
}

private func simulatorSDK() throws -> String {
    let (_, output) = try runTool(["--sdk", "iphonesimulator", "--show-sdk-path"])
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}

final class ObjCCodeGenerationTests: XCTestCase {
    func generated() throws -> URL {
        let layout = try layoutForTestSchema()
        let files = try ObjCCodeGenerator.generate(layout: layout, schemaHash: 0x1234)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("swifttl-objc-\(UUID().uuidString)")
        for (path, contents) in files {
            let url = root.appendingPathComponent("Sources").appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
        // The headers are static: the generated source must compile against the checked-in ones.
        try FileManager.default.createDirectory(at: root.appendingPathComponent("PublicHeaders/TelegramApiObjC"), withIntermediateDirectories: true)
        for header in ["TelegramApiObjC.h", "TLApiTypes.h", "TLObject.h", "TLEngine.h", "TLSchema.h"] {
            try FileManager.default.copyItem(at: runtimeHeader.deletingLastPathComponent().appendingPathComponent(header), to: root.appendingPathComponent("PublicHeaders/TelegramApiObjC/\(header)"))
        }
        let modulemap = "module TelegramApiObjC { umbrella header \"TelegramApiObjC/TelegramApiObjC.h\"\n export * }\n"
        try modulemap.write(to: root.appendingPathComponent("PublicHeaders/module.modulemap"), atomically: true, encoding: .utf8)
        return root
    }

    func typecheck(_ source: String, in root: URL) throws -> (Int32, String) {
        let probe = root.appendingPathComponent("probe-\(UUID().uuidString).swift")
        try source.write(to: probe, atomically: true, encoding: .utf8)
        return try runTool(["swiftc", "-typecheck", "-sdk", try simulatorSDK(), "-target", "arm64-apple-ios15.0-simulator",
                            "-I", root.appendingPathComponent("PublicHeaders").path, probe.path])
    }

    // A generated header would sit on both Bazel's and SwiftPM's include paths; only the table is generated.
    func testEmitsOnlyTheSchemaData() throws {
        let files = try ObjCCodeGenerator.generate(layout: try layoutForTestSchema(), schemaHash: 0x1234)
        XCTAssertEqual(Array(files.keys), ["TLApiSchemaData.m"])
    }

    func testGeneratedObjCCompilesWarningFreeWithoutARC() throws {
        let root = try generated()
        let (status, output) = try runTool(["clang", "-fsyntax-only", "-fmodules", "-fno-objc-arc", "-Wall", "-Wextra", "-Werror",
                                            "-Wno-unused-parameter", "-Wno-missing-field-initializers",
                                            "-I", root.appendingPathComponent("PublicHeaders").path,
                                            root.appendingPathComponent("Sources/TLApiSchemaData.m").path])
        XCTAssertEqual(status, 0, output)
    }

    func testNoGeneratedClasses() throws {
        let layout = try layoutForTestSchema()
        let files = try ObjCCodeGenerator.generate(layout: layout, schemaHash: 0x1234)
        for (path, contents) in files {
            XCTAssertFalse(contents.contains("@interface TLApi"), path)
            XCTAssertFalse(contents.contains("@implementation"), path)
        }
        let source = files["TLApiSchemaData.m"]!
        XCTAssertTrue(source.contains("const uint32_t TLApiTypeCount = 7;"))
        XCTAssertTrue(source.contains("const uint32_t TLApiConstructorCount = 9;"))
        XCTAssertTrue(source.contains("const uint32_t TLApiFunctionCount = 2;"))
        XCTAssertTrue(source.contains("const uint64_t TLApiSchemaHash = 0x1234ull;"))
    }

    // TLObjectAllocate is the only way to make an object: it sizes the storage from the
    // constructor. A bare +alloc made a header-only object that -dealloc would read past.
    func testObjectsAreMadeOnlyByTLObjectAllocate() throws {
        let root = try generated()
        for (name, body) in [("alloc", "(void)[TLObject alloc];"), ("init", "(void)[(TLObject *)nil tl_initWithInfo:TLApiConstructorAt(0)];")] {
            let source = root.appendingPathComponent("Sources/\(name)-probe.m")
            try "#import <TelegramApiObjC/TelegramApiObjC.h>\nvoid probe(void) { \(body) }\n".write(to: source, atomically: true, encoding: .utf8)
            let (status, output) = try runTool(["clang", "-fsyntax-only", "-fmodules", "-fno-objc-arc", "-Werror",
                                                "-I", root.appendingPathComponent("PublicHeaders").path, source.path])
            XCTAssertNotEqual(status, 0, "\(name) compiled: \(output)")
        }
    }

    func testSwiftImportsTheTableAPI() throws {
        let root = try generated()
        let (status, output) = try typecheck("""
        import TelegramApiObjC
        let object: TLObject = TLObjectAllocate(TLApiConstructorAt(0))
        let call: TLObject = TLObjectAllocate(TLApiFunctionConstructorAt(0))
        let index: UInt16 = object.tl_caseIndex
        let type: UnsafePointer<TLTypeInfo> = TLApiTypeAt(0)
        let function: UnsafePointer<TLFunctionInfo> = TLApiFunctionAt(0)
        let info: UnsafePointer<TLFunctionInfo> = TLObjectFunctionInfo(call)
        print(object, index, type, function, info, TLApiSchemaHash, TLApiTypeCount, TLApiConstructorCount, TLApiFunctionCount)
        """, in: root)
        XCTAssertEqual(status, 0, output)
    }

    func testRootHidesInheritedMembersFromSwift() throws {
        let root = try generated()
        let (status, output) = try typecheck("""
        import TelegramApiObjC
        let object: TLObject = TLObjectAllocate(TLApiConstructorAt(0))
        _ = object.hash
        _ = object.description
        """, in: root)
        XCTAssertNotEqual(status, 0)
        XCTAssertTrue(output.contains("has no member 'hash'"), output)
        XCTAssertTrue(output.contains("has no member 'description'"), output)
    }
}
