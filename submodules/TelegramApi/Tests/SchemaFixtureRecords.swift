import Foundation
@testable import TelegramApi

private func hex(_ data: Data) -> String {
    return data.map { String(format: "%02x", $0) }.joined()
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
/// the reader stops, which truncated prefixes still parse, and the logger's rendering. Building it
/// runs every path a value takes through the engine, which `LeakTests` checks for leaks.
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
