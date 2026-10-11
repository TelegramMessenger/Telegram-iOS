import Foundation
import XCTest
@testable import TelegramApi

private func hex(_ data: Data) -> String {
    return data.map { String(format: "%02x", $0) }.joined()
}

private func serialized(_ value: Any) -> Data {
    let buffer = Buffer()
    Api.serializeObject(value, buffer: buffer, boxed: true)
    return buffer.makeData()
}

final class GoldenTests: XCTestCase {
    // Set TLAPI_GOLDENS_OUT=/path/Goldens.swift to (re)record. Only ever record on
    // the unmodified generator output (Task 1); afterwards the goldens are the contract.
    func testRecordGoldensIfRequested() throws {
        guard let path = ProcessInfo.processInfo.environment["TLAPI_GOLDENS_OUT"] else { return }
        var out = "// Recorded by GoldenTests on the unmodified SwiftTL output. Do not edit by hand.\n"
        func dict(_ name: String, _ f: (Any) -> String) -> String {
            var s = "let \(name): [String: String] = [\n"
            for fixture in goldenFixtures {
                s += "    \(String(reflecting: fixture.name)): \(String(reflecting: f(fixture.value))),\n"
            }
            return s + "]\n"
        }
        out += dict("goldenBytes") { hex(serialized($0)) }
        out += dict("goldenDescriptions") { loggerDescription(redact: false, of: $0) }
        out += dict("goldenRedactedDescriptions") { loggerDescription(redact: true, of: $0) }
        try out.write(toFile: path, atomically: true, encoding: .utf8)
    }

    func testSerializedBytesMatchGoldens() {
        for fixture in goldenFixtures {
            XCTAssertEqual(hex(serialized(fixture.value)), goldenBytes[fixture.name], fixture.name)
        }
    }

    func testParseThenReserializeIsIdentical() {
        for fixture in goldenFixtures {
            let bytes = serialized(fixture.value)
            guard let parsed = Api.parse(Buffer(data: bytes)) else {
                XCTFail("\(fixture.name): parse returned nil")
                continue
            }
            XCTAssertEqual(hex(serialized(parsed)), hex(bytes), fixture.name)
            XCTAssertEqual(loggerDescription(redact: false, of: parsed), goldenDescriptions[fixture.name], fixture.name)
        }
    }

    func testDescriptionsMatchGoldens() {
        for fixture in goldenFixtures {
            XCTAssertEqual(loggerDescription(redact: false, of: fixture.value), goldenDescriptions[fixture.name], fixture.name)
            XCTAssertEqual(loggerDescription(redact: true, of: fixture.value), goldenRedactedDescriptions[fixture.name], fixture.name)
        }
    }

    func testRedactionIsActuallyApplied() {
        // Guards against goldens that were recorded with redaction already broken.
        XCTAssertTrue(goldenRedactedDescriptions["attachMenuBots"]!.contains("phone: [[redacted]]"))
        XCTAssertFalse(goldenRedactedDescriptions["attachMenuBots"]!.contains("+15550100"))
        XCTAssertTrue(goldenRedactedDescriptions["inputPhoneContact"]!.contains("phone: [[redacted]]"))
        XCTAssertTrue(goldenRedactedDescriptions["updateShortMessage"]!.contains("message: [[redacted]]"))
        XCTAssertTrue(goldenDescriptions["attachMenuBots"]!.contains("+15550100"))
    }
}
