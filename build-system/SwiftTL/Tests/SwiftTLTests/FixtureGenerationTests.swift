import XCTest
@testable import SwiftTL

private let fixtureSchema = """
boolFalse#bc799737 = Bool;
boolTrue#997275b5 = Bool;
peerUser#59511722 user_id:long = Peer;
peerChat#36c6019a chat_id:long = Peer;
textPlain#744694e0 text:string = RichText;
textConcat#7e6260d7 texts:Vector<RichText> = RichText;
item#11111111 flags:# big:flags.31?true title:string note:flags.0?string owner:flags.1?Peer ids:Vector<long> blob:bytes = Item;
---functions---
items.getItem#22222222 flags:# peer:Peer hint:flags.0?int = Item;
items.getIds#33333333 = Vector<long>;
items.getPeers#44444444 = Vector<Peer>;
"""

// Eight constructors of one type each reference a different bare constructor: the helpers must
// come out in sorted order, not in the order of the resolver's dictionaries (per-process seed).
private let bareOrderSchema = """
leafA#50000000 = Leaf;
leafB#50000001 = Leaf;
leafC#50000002 = Leaf;
leafD#50000003 = Leaf;
leafE#50000004 = Leaf;
leafF#50000005 = Leaf;
leafG#50000006 = Leaf;
leafH#50000007 = Leaf;
holderA#60000000 value:leafA = Holder;
holderB#60000001 value:leafB = Holder;
holderC#60000002 value:leafC = Holder;
holderD#60000003 value:leafD = Holder;
holderE#60000004 value:leafE = Holder;
holderF#60000005 value:leafF = Holder;
holderG#60000006 value:leafG = Holder;
holderH#60000007 value:leafH = Holder;
---functions---
"""

private func generatedFixtures() throws -> String {
    guard case let .flat(constructors, functions) = try DescriptionParser.parse(data: fixtureSchema) else { throw XCTSkip() }
    let types = try Resolver.resolveTypes(constructors: constructors)
    let resolvedFunctions = try Resolver.resolveFunctions(types: types, functionDescriptions: functions)
    return try FixtureGenerator.generate(apiPrefix: "Api", types: types, functions: resolvedFunctions)
}

final class FixtureGenerationTests: XCTestCase {
    func testBareHelpersFollowSortedConstructorOrder() throws {
        guard case let .flat(constructors, functions) = try DescriptionParser.parse(data: bareOrderSchema) else { throw XCTSkip() }
        let types = try Resolver.resolveTypes(constructors: constructors)
        let source = try FixtureGenerator.generate(apiPrefix: "Api", types: types, functions: try Resolver.resolveFunctions(types: types, functionDescriptions: functions))
        let positions = "ABCDEFGH".map { source.range(of: "func fxc_Leaf_leaf\($0)()")?.lowerBound }
        XCTAssertTrue(positions.allSatisfy { $0 != nil }, source)
        XCTAssertEqual(positions.compactMap { $0 }, positions.compactMap { $0 }.sorted())
    }

    func testMinimalHelpersPickTheCheapestConstructor() throws {
        let source = try generatedFixtures()
        XCTAssertTrue(source.contains("func fx_Bool() -> Api.Bool {\n    return Api.Bool.boolFalse\n}"))
        XCTAssertTrue(source.contains("func fx_RichText() -> Api.RichText {\n    return Api.RichText.textConcat(Api.RichText.Cons_textConcat(texts: []))\n}"))
        XCTAssertTrue(source.contains("func fx_Peer() -> Api.Peer {"))
    }

    func testFullVariantSetsEveryReferencedFlagBit() throws {
        let source = try generatedFixtures()
        // bits 31 (true flag), 0 and 1 → 0x80000003
        XCTAssertTrue(source.contains("name: \"Item.item#full\""))
        XCTAssertTrue(source.contains("flags: Int32(bitPattern: UInt32(2147483651))"))
        XCTAssertTrue(source.contains("owner: fx_Peer()"))
        XCTAssertTrue(source.contains("title: String(repeating: \"aü🙂\", count: 100) + \"b\""))  // 701 bytes: long form, unaligned
        XCTAssertTrue(source.contains("blob: Buffer(data: Data((0 ..< 301).map { UInt8(truncatingIfNeeded: $0) }))"))  // 301 bytes: long form, unaligned
    }

    func testEmptyVariantOmitsOptionalsAndEmptiesCollections() throws {
        let source = try generatedFixtures()
        XCTAssertTrue(source.contains("name: \"Item.item#empty\", make: { Api.Item.item(Api.Item.Cons_item(flags: 0, title: \"\", note: nil, owner: nil, ids: [], blob: Buffer())) }"))
        XCTAssertTrue(source.contains("name: \"Bool.boolTrue\", make: { Api.Bool.boolTrue }"))
    }

    func testFunctionFixturesCallBuildersAndSynthesizeResults() throws {
        let source = try generatedFixtures()
        XCTAssertTrue(source.contains("let call = Api.functions.items.getItem(flags: Int32(bitPattern: UInt32(1)), peer: fx_Peer(), hint: Int32("))
        XCTAssertTrue(source.contains("return (call.0, call.1, { call.2.parse($0) })"))
        XCTAssertTrue(source.contains("name: \"items.getIds#full\""))
        XCTAssertTrue(source.contains("b.appendInt32(481674261)"))
        XCTAssertTrue(source.contains("b.appendInt64(9)"))
        XCTAssertTrue(source.contains("fx_Peer().serialize(b, true)"))
    }
}
