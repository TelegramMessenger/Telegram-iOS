import XCTest
@testable import SwiftTL

final class SwiftCodeGenerationTests: XCTestCase {
    func generatedFiles(schema: String = testSchema) throws -> [String: String] {
        guard case let .flat(constructors, functionDescriptions) = try DescriptionParser.parse(data: schema) else { throw XCTSkip() }
        let types = try Resolver.resolveTypes(constructors: constructors)
        let functions = try Resolver.resolveFunctions(types: types, functionDescriptions: functionDescriptions)
        let layout = try TLSchemaLayout.build(apiPrefix: "Api", types: types, functions: functions)
        let sorted = types.sorted(by: { $0.name < $1.name })
        let constructorOrder = sorted.flatMap { type in type.constructors.values.sorted(by: { $0.name < $1.name }).map { (type.name, $0.name.value) } }
        let typeOrder = [
            (types: sorted.map { ($0.name, $0.constructors.values.sorted(by: { $0.name < $1.name }).map(\.name.value)) }, functions: [QualifiedName]()),
            (types: [(typeName: QualifiedName, constructorNames: [String])](), functions: functions.map(\.name).sorted()),
        ]
        return try CodeGenerator.generate(apiPrefix: "Api", types: types, functions: functions, constructorOrder: constructorOrder, typeOrder: typeOrder, layout: layout, schemaHash: 0x1234)
    }

    func testIndirectIsUnchanged() throws {
        let impl = try generatedFiles()["Api1.swift"]!
        XCTAssertTrue(impl.contains("    enum Peer: TypeConstructorDescription, TLObjectBacked, CustomStringConvertible {"))
        XCTAssertFalse(impl.contains("indirect enum Peer"))
    }

    func testRegistryAndHashInMainFile() throws {
        let main = try generatedFiles()["Api0.swift"]!
        XCTAssertTrue(main.contains("let tlTypeRegistry: [(TLObject) -> Any] = ["))
        XCTAssertTrue(main.contains("    { Api.Peer(tlObject: $0) },"))
        XCTAssertTrue(main.contains("let tlSwiftSchemaHash: UInt64 = 0x1234"))
        XCTAssertTrue(main.contains("@_alwaysEmitIntoClient public func tlVerifyClientLayout() {\n    if tlSchemaHashForClients() != 0x1234 {"))
    }

    func testParseSerializeAndDescriptionBodiesAreGone() throws {
        let impl = try generatedFiles()["Api1.swift"]!
        XCTAssertFalse(impl.contains("static func parse_"))
        XCTAssertFalse(impl.contains("public func serialize("))
        XCTAssertFalse(impl.contains("public func descriptionFields()"))
        XCTAssertTrue(impl.contains("public var tlBackingObject: TLObject {"))
        let main = try generatedFiles()["Api0.swift"]!
        XCTAssertFalse(main.contains("fileprivate let parsers"))
        XCTAssertTrue(main.contains("default:\n            return tlParseTopLevel(reader, signature: signature)"))
        XCTAssertTrue(main.contains("if let object = object as? TLObjectBacked {"))
    }

    func testConstructorsAreStructsOverStorage() throws {
        let impl = try generatedFiles()["Api1.swift"]!
        XCTAssertTrue(impl.hasPrefix("import TelegramApiObjC\n"))
        XCTAssertTrue(impl.contains("@frozen public struct Cons_peerUser {\n            @usableFromInline let tlObject: TLObject"))
        XCTAssertFalse(impl.contains("typealias Cons_"))
        XCTAssertFalse(impl.contains("TLApi_"))
        XCTAssertTrue(impl.contains("@usableFromInline init(tlObject object: TLObject) {"))
        XCTAssertTrue(impl.contains("self = .peerUser(Cons_peerUser(tlObject: object))"))
        XCTAssertTrue(impl.contains("return TLObjectSingleton(TLApiConstructorAt(6))"))   // boolTrue, by-id index 6
    }

    func testAccessorsReadAtTheLayoutOffsets() throws {
        let impl = try generatedFiles()["Api1.swift"]!
        XCTAssertTrue(impl.contains("@_alwaysEmitIntoClient var userId: Int64 {\n        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlBase(self.tlObject).load(fromByteOffset: 24, as: Int64.self) } }"))
        XCTAssertTrue(impl.contains("@_alwaysEmitIntoClient var accuracyRadius: Int32? {\n        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsPresent(self.tlObject, 48, 0) ? tlBase(self.tlObject).load(fromByteOffset: 28, as: Int32.self) : nil } }"))
        XCTAssertTrue(impl.contains("@_alwaysEmitIntoClient var command: String {\n        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlStringAt(self.tlObject, 32) } }"))
        XCTAssertTrue(impl.contains("@_alwaysEmitIntoClient var optPeer: Api.Peer? {\n        @inline(__always) get { withExtendedLifetime(self.tlObject) { tlIsNull(self.tlObject, 56) ? nil : Api.Peer(tlObject: tlObjectAt(self.tlObject, 56)) } }"))
        XCTAssertTrue(impl.contains("@_alwaysEmitIntoClient var chats: [Api.Peer] {\n        @inline(__always) get { withExtendedLifetime(self.tlObject) { Api.Peer.tlArray(self.tlObject, 32) } }"))
    }

    func testInitializersStoreAtTheLayoutOffsets() throws {
        let impl = try generatedFiles()["Api1.swift"]!
        XCTAssertTrue(impl.contains("init(flags: Int32, lat: Double, long: Double, accuracyRadius: Int32?) {\n        let _tlObject = TLObjectAllocate(TLApiConstructorAt(2))\n        var _tlPresent: UInt64 = 0\n        tlStore(_tlObject, 24, flags)\n        tlStore(_tlObject, 32, lat)\n        tlStore(_tlObject, 40, long)\n        if let _tlValue = accuracyRadius { tlStore(_tlObject, 28, _tlValue); _tlPresent |= 1 << 0 }\n        tlStore(_tlObject, 48, _tlPresent)\n        self.init(tlObject: _tlObject)\n    }"))
        XCTAssertTrue(impl.contains("tlStoreReference(_tlObject, 32, command as NSString)"))
    }

    func testFunctionBuildersFillStorage() throws {
        let functions = try generatedFiles().values.first { $0.contains("static func getItem(") }!
        XCTAssertTrue(functions.contains("let _tlObject = TLObjectAllocate(TLApiFunctionConstructorAt(1))"))
        XCTAssertTrue(functions.contains("tlStoreReference(_tlObject, 32, peer.tlObject)"))
        XCTAssertTrue(functions.contains("if let _tlValue = key { tlStore(_tlObject, 40, TLInt256(_0: _tlValue._0, _1: _tlValue._1, _2: _tlValue._2, _3: _tlValue._3)); _tlPresent |= 1 << 1 }"))
        XCTAssertTrue(functions.contains("return tlFunction(_tlObject)"))
    }

    /// TL fields named like the generator's locals must still store themselves, not the locals:
    /// `tlStore` is generic, so a shadowed `object`/`present` would compile and corrupt storage.
    func testFieldNamesCannotShadowGeneratedLocals() throws {
        let schema = """
        clash#44444444 flags:# object:long present:int maybe:flags.0?int value:string = Clash;
        """
        let impl = try generatedFiles(schema: schema)["Api1.swift"]!
        XCTAssertTrue(impl.contains("init(flags: Int32, object: Int64, present: Int32, maybe: Int32?, value: String) {"))
        XCTAssertTrue(impl.contains("let _tlObject = TLObjectAllocate(TLApiConstructorAt(0))"))
        XCTAssertTrue(impl.contains("tlStore(_tlObject, 40, object)"))
        XCTAssertTrue(impl.contains("tlStore(_tlObject, 28, present)"))
        XCTAssertTrue(impl.contains("if let _tlValue = maybe { tlStore(_tlObject, 32, _tlValue); _tlPresent |= 1 << 0 }"))
        XCTAssertTrue(impl.contains("tlStoreReference(_tlObject, 48, value as NSString)"))
        XCTAssertTrue(impl.contains("tlStore(_tlObject, 56, _tlPresent)"))
        XCTAssertFalse(impl.contains("let object ="))
        XCTAssertFalse(impl.contains("var present: UInt64"))
    }
}
