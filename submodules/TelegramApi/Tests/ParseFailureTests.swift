import Foundation
import XCTest
@testable import TelegramApi

// Literal expectations for malformed input, taken from the Swift parser the engine replaced
// (this file passes unchanged against fc5a7cc64b). An unknown constructor must be logged with
// its exact id, including one that follows a field that already failed, so the engine has to
// stop where the Swift parser stopped.

private func le32(_ value: UInt32) -> [UInt8] {
    return withUnsafeBytes(of: value.littleEndian) { Array($0) }
}

private func parseLogging(_ bytes: [UInt8]) -> (Any?, [String]) {
    var lines: [String] = []
    setTelegramApiLogger { lines.append($0) }
    let result = Api.parse(Buffer(data: Data(bytes)))
    setTelegramApiLogger { _ in }
    return (result, lines)
}

// updateNotifySettings#bec268ef peer:NotifyPeer notify_settings:PeerNotifySettings = Update
private let updateNotifySettings: UInt32 = 0xbec268ef
// help.support#17c6b5f6 phone_number:string user:User = help.Support
private let helpSupport: UInt32 = 0x17c6b5f6
// botCommand#9852d6d2 flags:# ephemeral:flags.0?true command:string description:string
private let botCommand: UInt32 = 0x9852d6d2

private let unknownA: UInt32 = 0x7ffffff1
private let unknownB: UInt32 = 0x7ffffff2

final class ParseFailureTests: XCTestCase {
    func testUnknownTopLevelIdIsLoggedExactly() {
        let (result, lines) = parseLogging(le32(unknownA))
        XCTAssertNil(result)
        XCTAssertEqual(lines, ["Type constructor 7ffffff1 not found"])
    }

    func testNestedUnknownIdsAreLoggedExactly() {
        let (result, lines) = parseLogging(le32(updateNotifySettings) + le32(unknownA) + le32(unknownB))
        XCTAssertNil(result)
        XCTAssertEqual(lines, ["Type constructor 7ffffff1 not found", "Type constructor 7ffffff2 not found"])
    }

    /// A primitive's id where an object is expected fails the field after consuming the
    /// primitive's value, so the next field's id is read from the right place.
    func testPrimitiveIdInAnObjectFieldConsumesItsValue() {
        let primitives: [(String, UInt32, [UInt8])] = [
            ("int", 0xa8509bda, [UInt8](repeating: 0xab, count: 4)),
            ("long", 0x22076cba, [UInt8](repeating: 0xab, count: 8)),
            ("double", 0x2210c154, [UInt8](repeating: 0xab, count: 8)),
            ("int256", 0x0929c32f, [UInt8](repeating: 0xab, count: 32)),
            ("string", 0xb5286e24, [2, 0x61, 0x62, 0]),
        ]
        for (name, id, payload) in primitives {
            let (result, lines) = parseLogging(le32(updateNotifySettings) + le32(id) + payload + le32(unknownA))
            XCTAssertNil(result, name)
            XCTAssertEqual(lines, ["Type constructor 7ffffff1 not found"], name)
        }
    }

    /// A string whose length runs past the end still skips its padding before the next field.
    func testOverlongStringSkipsItsPadding() {
        let shortForm: [UInt8] = [200, 0xaa, 0xaa, 0xaa]            // 200 + 1 → 3 bytes of padding
        let longForm: [UInt8] = [254, 0x01, 0x04, 0x00, 0xaa, 0xaa, 0xaa] // 1025 → 3 bytes of padding
        for (name, string) in [("short", shortForm), ("long", longForm)] {
            let (result, lines) = parseLogging(le32(helpSupport) + string + le32(unknownA))
            XCTAssertNil(result, name)
            XCTAssertEqual(lines, ["Type constructor 7ffffff1 not found"], name)
        }
    }

    func testStringDecoding() {
        func tlString(_ bytes: [UInt8]) -> [UInt8] {
            let padding = (4 - (bytes.count + 1) % 4) % 4
            return [UInt8(bytes.count)] + bytes + [UInt8](repeating: 0, count: padding)
        }
        let cases: [(String, [UInt8], String)] = [
            ("invalid UTF-8", [0xff, 0xfe], ""),
            ("leading BOM", [0xef, 0xbb, 0xbf, 0x41], "A"),                  // stripped
            ("embedded NUL", [0x61, 0x00, 0x62], "a\u{0}b"),
            ("multi-byte", [0xc3, 0xbc, 0xf0, 0x9f, 0x99, 0x82], "ü🙂"),
        ]
        for (name, bytes, expected) in cases {
            let (result, lines) = parseLogging(le32(botCommand) + le32(0) + tlString(bytes) + tlString([0x78]))
            guard case let .botCommand(command)? = result as? Api.BotCommand else {
                XCTFail(name)
                continue
            }
            XCTAssertEqual(Array(command.command.unicodeScalars), Array(expected.unicodeScalars), name)
            XCTAssertEqual(command.description, "x", name)
            XCTAssertEqual(lines, [], name)
        }
    }
}
