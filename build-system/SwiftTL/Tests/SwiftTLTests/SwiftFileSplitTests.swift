import XCTest
@testable import SwiftTL

final class SwiftFileSplitTests: XCTestCase {
    private func resolved() throws -> (types: [Resolver.SumType], functions: [Resolver.Function]) {
        guard case let .flat(constructors, functionDescriptions) = try DescriptionParser.parse(data: testSchema) else {
            throw XCTSkip("unexpected layered schema")
        }
        let types = try Resolver.resolveTypes(constructors: constructors)
        let functions = try Resolver.resolveFunctions(types: types, functionDescriptions: functionDescriptions)
        return (types, functions)
    }

    private func typeOrder(fileCount: Int) throws -> [SwiftFileSplit.FileContents] {
        let (types, functions) = try self.resolved()
        return try SwiftFileSplit.typeOrder(types: types, functions: functions, fileCount: fileCount)
    }

    // Api0 is the registry file; typeOrder describes Api1 ... Api{fileCount - 1}.
    func testDescribesExactlyTheRequestedFiles() throws {
        for fileCount in [3, 4, 5, 9, 20] {
            XCTAssertEqual(try self.typeOrder(fileCount: fileCount).count, fileCount - 1, "fileCount \(fileCount)")
        }
    }

    func testFunctionsGoLastAndEveryTypeAppearsOnceInSortedOrder() throws {
        let order = try self.typeOrder(fileCount: 5)
        XCTAssertEqual(order.last?.functions.map(\.description), ["items.getIds", "items.getItem"])
        XCTAssertEqual(order.last?.types.count, 0)
        XCTAssertTrue(order.dropLast().allSatisfy { $0.functions.isEmpty })
        XCTAssertEqual(order.flatMap { $0.types.map(\.typeName.description) },
                       ["Bool", "BotCommand", "BotCommands", "InputGeoPoint", "Peer", "PhoneCallProtocol", "messages.Chats"])
        XCTAssertEqual(order[0].types.first?.constructorNames, ["boolFalse", "boolTrue"])
    }

    func testBalancesTypeFilesByConstructorCount() throws {
        // 9 constructors over 3 type files.
        let loads = try self.typeOrder(fileCount: 5).dropLast().map { $0.types.reduce(0) { $0 + $1.constructorNames.count } }
        XCTAssertEqual(loads.reduce(0, +), 9)
        XCTAssertLessThanOrEqual(loads.max() ?? 0, 4)
        XCTAssertGreaterThanOrEqual(loads.min() ?? 0, 2)
    }

    func testFilesBeyondTheTypesStayEmpty() throws {
        let typeFiles = try self.typeOrder(fileCount: 20).dropLast()
        XCTAssertEqual(typeFiles.count, 18)
        XCTAssertEqual(typeFiles.filter { !$0.types.isEmpty }.count, 7)
    }

    func testRejectsFewerThanThreeFiles() throws {
        XCTAssertThrowsError(try self.typeOrder(fileCount: 2))
    }

    func testGeneratesEveryFileIncludingEmptyOnes() throws {
        let (types, functions) = try self.resolved()
        let layout = try TLSchemaLayout.build(apiPrefix: "Api", types: types, functions: functions)
        let order = try SwiftFileSplit.typeOrder(types: types, functions: functions, fileCount: 20)
        let constructorOrder = order.flatMap { file in file.types.flatMap { type in type.constructorNames.map { (typeName: type.typeName, constructorName: $0) } } }
        let files = try CodeGenerator.generate(apiPrefix: "Api", types: types, functions: functions, constructorOrder: constructorOrder, typeOrder: order, layout: layout, schemaHash: 0x1234)
        XCTAssertEqual(Set(files.keys), Set((0 ..< 20).map { "Api\($0).swift" }))
        XCTAssertEqual(files["Api19.swift"]?.contains("static func getIds("), true)
    }
}
