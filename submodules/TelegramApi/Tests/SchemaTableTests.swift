import Foundation
import XCTest
import TelegramApiObjC
@testable import TelegramApi

final class SchemaTableTests: XCTestCase {
    func testHashesMatch() {
        XCTAssertEqual(TLApiSchemaHash, tlSwiftSchemaHash)
    }

    func testRegistryCoversEveryType() {
        XCTAssertEqual(Int(TLApiTypeCount), tlTypeRegistry.count)
    }

    func testConstructorsByIdAreSortedAndUnique() {
        var previous: UInt32?
        for i in 0 ..< TLApiConstructorCount {
            let info = TLApiConstructorAt(i).pointee
            if let previous = previous {
                XCTAssertLessThan(previous, info.constructorId)
            }
            previous = info.constructorId
        }
    }

    func testTypeTableAgreesWithConstructorInfos() {
        for typeIndex in 0 ..< TLApiTypeCount {
            let type = TLApiTypeAt(typeIndex).pointee
            for caseIndex in 0 ..< Int(type.constructorCount) {
                let info = type.constructors[caseIndex].pointee
                XCTAssertEqual(UInt32(info.typeIndex), typeIndex, String(cString: info.name))
                XCTAssertEqual(Int(info.caseIndex), caseIndex, String(cString: info.name))
            }
        }
    }

    func testFieldlessSingletonsRoundTripThroughTheRegistry() {
        for typeIndex in 0 ..< TLApiTypeCount {
            let type = TLApiTypeAt(typeIndex).pointee
            for caseIndex in 0 ..< Int(type.constructorCount) {
                let infoPointer = type.constructors[caseIndex]
                guard infoPointer.pointee.fieldCount == 0 else { continue }
                let description = (tlValue(TLObjectSingleton(infoPointer)) as! TypeConstructorDescription).descriptionFields()
                XCTAssertEqual(description.0, String(cString: infoPointer.pointee.name))
                XCTAssertTrue(description.1.isEmpty)
            }
        }
    }

    /// A client compiled against this TelegramApi (the test bundle is one) passes the inlined
    /// layout check; the literal it carries is the generator's hash.
    func testClientLayoutCheckPassesForAMatchingClient() {
        tlVerifyClientLayout()
        XCTAssertEqual(tlSchemaHashForClients(), TLApiSchemaHash)
    }
}
