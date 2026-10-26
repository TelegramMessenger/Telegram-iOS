import XCTest
@testable import SwiftTL

let testSchema = """
boolFalse#bc799737 = Bool;
boolTrue#997275b5 = Bool;
peerUser#59511722 user_id:long = Peer;
peerChat#36c6019a chat_id:long = Peer;
inputGeoPoint#48222faf flags:# lat:double long:double accuracy_radius:flags.0?int = InputGeoPoint;
phoneCallProtocol#fc878fc8 flags:# udp_p2p:flags.0?true min_layer:int library_versions:Vector<string> = PhoneCallProtocol;
messages.chats#64ff9fd5 flags:# chats:Vector<Peer> ids:Vector<long> blob:bytes opt_peer:flags.1?Peer = messages.Chats;
botCommand#9852d6d2 command:string description:string id:int = BotCommand;
botCommands#11111111 first:botCommand rest:Vector<botCommand> = BotCommands;
---functions---
items.getItem#22222222 flags:# peer:Peer hint:flags.0?int key:flags.1?int256 = Peer;
items.getIds#33333333 = Vector<long>;
"""

func layoutForTestSchema() throws -> TLSchemaLayout {
    guard case let .flat(constructors, functionDescriptions) = try DescriptionParser.parse(data: testSchema) else {
        throw XCTSkip("unexpected layered schema")
    }
    let types = try Resolver.resolveTypes(constructors: constructors)
    let functions = try Resolver.resolveFunctions(types: types, functionDescriptions: functionDescriptions)
    return try TLSchemaLayout.build(apiPrefix: "Api", types: types, functions: functions)
}

final class TLLayoutTests: XCTestCase {
    func testTypeAndCaseIndicesFollowSortedOrder() throws {
        let layout = try layoutForTestSchema()
        XCTAssertEqual(layout.types.map(\.type.name.description), ["Bool", "BotCommand", "BotCommands", "InputGeoPoint", "Peer", "PhoneCallProtocol", "messages.Chats"])
        let peer = layout.typeLayout(for: QualifiedName(namespace: nil, value: "Peer"))
        XCTAssertEqual(peer.typeIndex, 4)
        XCTAssertEqual(peer.objcClassName, "TLApi_Peer")
        XCTAssertEqual(peer.constructors.map(\.constructor.name.value), ["peerChat", "peerUser"])
        XCTAssertEqual(peer.constructors.map(\.caseIndex), [0, 1])
        XCTAssertEqual(peer.payloadCaseCount, 2)
        XCTAssertEqual(layout.typeLayout(for: QualifiedName(namespace: "messages", value: "Chats")).objcClassName, "TLApi_messages_Chats")
    }

    func testFieldKindsOptionalityAndPresenceBits() throws {
        let layout = try layoutForTestSchema()
        let geo = layout.constructorLayout(for: QualifiedName(namespace: nil, value: "InputGeoPoint"), constructorName: "inputGeoPoint")
        XCTAssertEqual(geo.fields.map(\.swiftName), ["flags", "lat", "long", "accuracyRadius"])
        XCTAssertEqual(geo.fields.map(\.objcName), ["flags", "lat", "long_", "accuracyRadius"])
        XCTAssertEqual(geo.fields.map(\.kind), [.int32, .double, .double, .int32])
        XCTAssertEqual(geo.fields[3].isOptional, true)
        XCTAssertEqual(geo.fields[3].flagsFieldIndex, 0)
        XCTAssertEqual(geo.fields[3].flagBit, 0)
        XCTAssertEqual(geo.fields[3].presenceBit, 0)
        XCTAssertTrue(geo.hasPresent)
        XCTAssertFalse(geo.isDirectlyImported)
    }

    func testTrueFlagsAreNotFields() throws {
        let layout = try layoutForTestSchema()
        let proto = layout.constructorLayout(for: QualifiedName(namespace: nil, value: "PhoneCallProtocol"), constructorName: "phoneCallProtocol")
        XCTAssertEqual(proto.fields.map(\.swiftName), ["flags", "minLayer", "libraryVersions"])
        XCTAssertEqual(proto.fields[2].kind, .vector)
        XCTAssertEqual(proto.fields[2].elementKind, .string)
        XCTAssertTrue(proto.fields[2].isBoxedVector)
    }

    func testObjectAndVectorFieldsAndDirectImport() throws {
        let layout = try layoutForTestSchema()
        let chats = layout.constructorLayout(for: QualifiedName(namespace: "messages", value: "Chats"), constructorName: "chats")
        XCTAssertEqual(chats.objcClassName, "TLApi_messages_Chats_chats")
        XCTAssertEqual(chats.fields.map(\.kind), [.int32, .vector, .vector, .bytes, .object])
        XCTAssertEqual(chats.fields[1].elementKind, .object)
        XCTAssertEqual(chats.fields[1].objectType, QualifiedName(namespace: nil, value: "Peer"))
        XCTAssertEqual(chats.fields[4].swiftType, "Api.Peer?")
        XCTAssertEqual(chats.fields[4].flagsFieldIndex, 0)
        XCTAssertFalse(chats.hasPresent)
        let user = layout.constructorLayout(for: QualifiedName(namespace: nil, value: "Peer"), constructorName: "peerUser")
        XCTAssertTrue(user.isDirectlyImported)
    }

    func testKeywordFieldNames() throws {
        let layout = try layoutForTestSchema()
        let command = layout.constructorLayout(for: QualifiedName(namespace: nil, value: "BotCommand"), constructorName: "botCommand")
        XCTAssertEqual(command.fields.map(\.swiftName), ["command", "description", "id"])
        XCTAssertEqual(command.fields.map(\.objcName), ["command", "description_", "id_"])
        XCTAssertEqual(command.fields.map(\.descriptionName), ["command", "description", "id"])
        XCTAssertEqual("protocol".camelCasedAndEscaped, "`protocol`")
        XCTAssertEqual(objcFieldName(for: "protocol"), "protocol")
    }

    func testFieldlessConstructors() throws {
        let layout = try layoutForTestSchema()
        let bool = layout.typeLayout(for: QualifiedName(namespace: nil, value: "Bool"))
        XCTAssertEqual(bool.payloadCaseCount, 0)
        XCTAssertTrue(bool.constructors.allSatisfy { $0.fields.isEmpty })
    }

    func testBareConstructorFields() throws {
        let layout = try layoutForTestSchema()
        let commands = layout.constructorLayout(for: QualifiedName(namespace: nil, value: "BotCommands"), constructorName: "botCommands")
        XCTAssertEqual(commands.fields.map(\.kind), [.object, .vector])
        XCTAssertEqual(commands.fields[0].objectType, QualifiedName(namespace: nil, value: "BotCommand"))
        XCTAssertEqual(commands.fields[0].bareConstructorIndex, 0)
        XCTAssertEqual(commands.fields[0].swiftType, "Api.BotCommand")
        XCTAssertEqual(commands.fields[1].elementKind, .object)
        XCTAssertEqual(commands.fields[1].bareConstructorIndex, 0)
        XCTAssertTrue(commands.fields[1].isBoxedVector)
        XCTAssertEqual(commands.fields[1].swiftType, "[Api.BotCommand]")
    }

    func testRejectsInt256Fields() throws {
        let schema = "a#00000001 key:int256 = A;\n---functions---\n"
        guard case let .flat(constructors, _) = try DescriptionParser.parse(data: schema) else { return XCTFail() }
        XCTAssertThrowsError(try TLSchemaLayout.build(apiPrefix: "Api", types: Resolver.resolveTypes(constructors: constructors)))
    }

    func testObjCMangling() {
        XCTAssertEqual(objcFieldName(for: "hash"), "hash_")
        XCTAssertEqual(objcFieldName(for: "description"), "description_")
        XCTAssertEqual(objcFieldName(for: "newMessage"), "tlNewMessage")
        XCTAssertEqual(objcFieldName(for: "copyText"), "tlCopyText")
        XCTAssertEqual(objcFieldName(for: "new"), "tlNew")
        XCTAssertEqual(objcFieldName(for: "mutableCopyValue"), "tlMutableCopyValue")
        XCTAssertEqual(objcFieldName(for: "news"), "news")
        XCTAssertEqual(objcFieldName(for: "initial"), "initial")
        XCTAssertEqual(objcFieldName(for: "self"), "self_")
        XCTAssertEqual(objcFieldName(for: "present"), "present_")
        XCTAssertEqual(objcFieldName(for: "userId"), "userId")
    }

    func testSwiftBridgedFieldsNeedNoConversion() throws {
        let layout = try layoutForTestSchema()
        let command = layout.constructorLayout(for: QualifiedName(namespace: nil, value: "BotCommand"), constructorName: "botCommand")
        XCTAssertTrue(command.isDirectlyImported)                       // strings bridge directly
        let proto = layout.constructorLayout(for: QualifiedName(namespace: nil, value: "PhoneCallProtocol"), constructorName: "phoneCallProtocol")
        XCTAssertTrue(proto.isDirectlyImported)                         // [String] bridges directly
        let chats = layout.constructorLayout(for: QualifiedName(namespace: "messages", value: "Chats"), constructorName: "chats")
        XCTAssertEqual(chats.fields.map(\.needsSwiftConversion), [false, true, true, true, true])
        XCTAssertEqual(chats.fields[1].ivarName, "_chats")
    }

    func testFunctionLayouts() throws {
        let schema = """
        peerUser#59511722 user_id:long = Peer;
        ---functions---
        items.getItem#22222222 flags:# peer:Peer hint:flags.0?int key:flags.1?int256 = Peer;
        items.getIds#33333333 = Vector<long>;
        """
        guard case let .flat(constructors, functionDescriptions) = try DescriptionParser.parse(data: schema) else { return XCTFail() }
        let types = try Resolver.resolveTypes(constructors: constructors)
        let functions = try Resolver.resolveFunctions(types: types, functionDescriptions: functionDescriptions)
        let layout = try TLSchemaLayout.build(apiPrefix: "Api", types: types, functions: functions)
        let getItem = layout.functions.first { $0.function.name.value == "getItem" }!
        XCTAssertEqual(getItem.objcClassName, "TLApiFunction_items_getItem")
        XCTAssertEqual(getItem.fields.map(\.kind), [.int32, .object, .int32, .int256])
        XCTAssertTrue(getItem.hasPresent)
        XCTAssertEqual(getItem.result.kind, .object)
        let getIds = layout.functions.first { $0.function.name.value == "getIds" }!
        XCTAssertTrue(getIds.fields.isEmpty)
        XCTAssertEqual(getIds.result.kind, .vector)
        XCTAssertEqual(getIds.result.elementKind, .int64)
        XCTAssertTrue(getIds.result.isBoxedVector)
    }

    func testStorageLayoutMatchesClangIvarOrder() throws {
        let layout = try layoutForTestSchema()
        let geo = layout.constructorLayout(for: QualifiedName(namespace: nil, value: "InputGeoPoint"), constructorName: "inputGeoPoint")
        XCTAssertEqual(geo.fields.map(\.swiftName), ["flags", "lat", "long", "accuracyRadius"])   // schema order kept
        XCTAssertEqual(geo.fields.map(\.offset), [24, 32, 40, 28])
        XCTAssertEqual(geo.presentOffset, 48)
        XCTAssertEqual(geo.instanceSize, 56)

        let peer = layout.constructorLayout(for: QualifiedName(namespace: nil, value: "Peer"), constructorName: "peerUser")
        XCTAssertEqual(peer.fields.map(\.offset), [24])
        XCTAssertEqual(peer.presentOffset, -1)
        XCTAssertEqual(peer.instanceSize, 32)

        let command = layout.constructorLayout(for: QualifiedName(namespace: nil, value: "BotCommand"), constructorName: "botCommand")
        XCTAssertEqual(command.fields.map(\.swiftName), ["command", "description", "id"])
        XCTAssertEqual(command.fields.map(\.offset), [32, 40, 24])
        XCTAssertEqual(command.instanceSize, 48)

        let empty = layout.constructorLayout(for: QualifiedName(namespace: nil, value: "Bool"), constructorName: "boolTrue")
        XCTAssertEqual(empty.instanceSize, 24)
        XCTAssertEqual(empty.presentOffset, -1)
    }

    func testFunctionStorageLayout() throws {
        let layout = try layoutForTestSchema()
        let getItem = layout.functions.first { $0.function.name.value == "getItem" }!
        XCTAssertEqual(getItem.fields.map(\.swiftName), ["flags", "peer", "hint", "key"])
        XCTAssertEqual(getItem.fields.map(\.offset), [24, 32, 28, 40])   // key is int256: 32 bytes
        XCTAssertEqual(getItem.presentOffset, 72)
        XCTAssertEqual(getItem.instanceSize, 80)
        let getIds = layout.functions.first { $0.function.name.value == "getIds" }!
        XCTAssertEqual(getIds.instanceSize, 24)
        XCTAssertEqual(getIds.presentOffset, -1)
    }
}
