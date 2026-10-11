import Foundation
import XCTest
@testable import TelegramApi

private func hex(_ data: Data) -> String {
    return data.map { String(format: "%02x", $0) }.joined()
}

private func fnv1a64(_ text: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in text.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return hash
}

private final class LogCapture {
    private let lock = NSLock()
    private var lines: [String] = []

    func append(_ line: String) {
        self.lock.lock()
        self.lines.append(line)
        self.lock.unlock()
    }

    func take() -> [String] {
        self.lock.lock()
        defer { self.lock.unlock() }
        let result = self.lines
        self.lines = []
        return result
    }
}

private let logCapture = LogCapture()

private func capturingLogs<R>(_ body: () -> R) -> (R, [String]) {
    setTelegramApiLogger { line in logCapture.append(line) }
    _ = logCapture.take()
    let result = body()
    return (result, logCapture.take())
}

private func serialized(_ value: Any) -> Data {
    let buffer = Buffer()
    Api.serializeObject(value, buffer: buffer, boxed: true)
    return buffer.makeData()
}

/// Everything observable about one constructor fixture: bytes, round trip, logs, where
/// the reader stops, which truncated prefixes still parse, and the logger's rendering.
func schemaConstructorRecord(_ fixture: SchemaConstructorFixture) -> String {
    let value = fixture.make()
    let bytes = serialized(value)
    var parts = [fixture.name, hex(bytes)]
    let (parsed, logs) = capturingLogs { Api.parse(Buffer(data: bytes)) }
    if let parsed = parsed {
        parts.append("roundtrip=\(hex(serialized(parsed)) == hex(bytes))")
        parts.append(loggerDescription(redact: false, of: parsed))
    } else {
        parts.append("parse=nil")
    }
    parts.append("logs=\(logs.joined(separator: ";"))")
    let reader = BufferReader(Buffer(data: bytes + Data(repeating: 0xab, count: 8)))
    if let signature = reader.readInt32() {
        _ = Api.parse(reader, signature: signature)
    }
    parts.append("offset=\(reader.offset)")
    var parsingPrefixes: [Int] = []
    for length in 0 ..< bytes.count where Api.parse(Buffer(data: bytes.prefix(length))) != nil {
        parsingPrefixes.append(length)
    }
    parts.append("prefixes=\(parsingPrefixes)")
    parts.append(loggerDescription(redact: false, of: value))
    parts.append(loggerDescription(redact: true, of: value))
    return parts.joined(separator: "|")
}

/// Everything observable about one function fixture: request bytes, the logged request
/// with and without redaction, and parsing of a synthesized response and its prefixes.
func schemaFunctionRecord(_ fixture: SchemaFunctionFixture) -> String {
    let (description, buffer, parse) = fixture.make()
    var parts = [fixture.name, hex(buffer.makeData())]
    parts.append(loggerFunctionDescription(redact: false, of: description))
    parts.append(loggerFunctionDescription(redact: true, of: description))
    let result = fixture.resultBytes().makeData()
    let (parsed, logs) = capturingLogs { parse(Buffer(data: result)) }
    parts.append(parsed.map { loggerDescription(redact: false, of: $0) } ?? "result=nil")
    parts.append("logs=\(logs.joined(separator: ";"))")
    var parsingPrefixes: [Int] = []
    for length in 0 ..< result.count where parse(Buffer(data: result.prefix(length))) != nil {
        parsingPrefixes.append(length)
    }
    parts.append("prefixes=\(parsingPrefixes)")
    return parts.joined(separator: "|")
}

final class SchemaGoldenTests: XCTestCase {
    private func currentRecords() -> [(String, String)] {
        return schemaConstructorFixtures.map { ($0.name, schemaConstructorRecord($0)) }
            + schemaFunctionFixtures.map { ($0.name, schemaFunctionRecord($0)) }
    }

    // TLAPI_SCHEMA_GOLDENS_OUT=<path> records digests. Only ever on pre-engine code (the old generated
    // Swift built with these test files), never on the engine: a recording there pins nothing.
    // TLAPI_SCHEMA_DUMP=<path> writes every full record, for diffing two implementations.
    func testRecordIfRequested() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["TLAPI_SCHEMA_GOLDENS_OUT"] != nil || environment["TLAPI_SCHEMA_DUMP"] != nil else { return }
        let records = self.currentRecords()
        if let path = environment["TLAPI_SCHEMA_DUMP"] {
            try records.map { $0.1 }.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
        }
        if let path = environment["TLAPI_SCHEMA_GOLDENS_OUT"] {
            var out = "// Recorded by SchemaGoldenTests on pre-engine code. Do not edit.\n"
            out += "let schemaGoldenDigests = \"\"\"\n"
            for (name, record) in records {
                out += "\(name) \(String(format: "%016llx", fnv1a64(record)))\n"
            }
            out += "\"\"\"\n"
            try out.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    func testEveryFixtureMatchesItsGolden() {
        var goldens: [String: String] = [:]
        for line in schemaGoldenDigests.split(separator: "\n") {
            let parts = line.split(separator: " ")
            if parts.count == 2 {
                goldens[String(parts[0])] = String(parts[1])
            }
        }
        XCTAssertFalse(goldens.isEmpty, "no goldens recorded")
        let records = self.currentRecords()
        XCTAssertEqual(records.count, goldens.count)
        var mismatches = 0
        for (name, record) in records {
            let digest = String(format: "%016llx", fnv1a64(record))
            if goldens[name] != digest {
                mismatches += 1
                if mismatches <= 20 {
                    XCTFail("\(name): \(String(record.prefix(1500)))")
                }
            }
        }
        XCTAssertEqual(mismatches, 0)
    }
}
