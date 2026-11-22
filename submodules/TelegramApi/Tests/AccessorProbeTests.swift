import Foundation
import XCTest
import TelegramApiObjC
@testable import TelegramApi

private func rendered(_ value: Any?) -> String {
    guard let value = value else { return "nil" }
    if case Optional<Any>.none = value as Any? { return "nil" }
    return loggerDescription(redact: false, of: value)
}

/// Swift accessors (generator offsets baked into Swift) against the table-driven description
/// (offsets from the decoded blob) for every field of every fixture.
final class AccessorProbeTests: XCTestCase {
    func testEveryAccessorReadsWhatTheTableDescribes() {
        var covered = Set<String>()
        for fixture in schemaConstructorFixtures {
            let key = String(fixture.name.split(separator: "#")[0])
            guard let probe = schemaAccessorProbes[key] else { continue }
            let value = fixture.make()
            let viaAccessors = probe(value)
            let viaTable = tlDescriptionFields((value as! TLObjectBacked).tlBackingObject).1
            XCTAssertEqual(viaAccessors.map(\.0), viaTable.map(\.0), fixture.name)
            for (a, t) in zip(viaAccessors, viaTable) {
                XCTAssertEqual(rendered(a.1), rendered(t.1.value), "\(fixture.name).\(a.0)")
            }
            covered.insert(key)
        }
        // Every payload constructor's accessors were exercised by at least one fixture.
        XCTAssertEqual(covered, Set(schemaAccessorProbes.keys))
        XCTAssertGreaterThan(covered.count, 1300)
    }
}
