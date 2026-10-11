import Foundation
import XCTest
import TelegramApiObjC
@testable import TelegramApi

private func swiftSerialized(_ value: Any) -> Data {
    let buffer = Buffer()
    Api.serializeObject(value, buffer: buffer, boxed: true)
    return buffer.makeData()
}

final class EngineTests: XCTestCase {
    func testUnknownAndWrongTypeIdsFail() {
        // Unknown top-level id: no object.
        var empty = TLReader(bytes: nil, length: 0, offset: 0)
        XCTAssertNil(TLParseConstructor(&empty, 0x7fff_fff1, TLAnyTypeIndex))
        // A Peer constructor where a Bool is expected fails, as `as? Api.Bool` did.
        let boolTypeIndex = (0 ..< TLApiTypeCount).first { String(cString: TLApiTypeAt($0).pointee.name) == "Bool" }!
        let reader = BufferReader(Buffer(data: swiftSerialized(Api.Peer.peerUser(Api.Peer.Cons_peerUser(userId: 1)))))
        let signature = reader.readInt32()!
        let result = tlWithReader(reader) { tlReader in TLParseConstructor(&tlReader, signature, UInt16(boolTypeIndex)) }
        XCTAssertNil(result)
    }

    /// A String bridged from an NSString can hold an unpaired UTF-16 surrogate. Swift's lossy
    /// UTF-8 conversion sent it as U+FFFD (EF BF BD); the field must never go out empty.
    func testUnpairedSurrogateIsSentAsReplacementCharacter() {
        let text = NSString(characters: [0x61, 0xD83D, 0x62], length: 3) as String
        let expected = Data([5, 0x61, 0xEF, 0xBF, 0xBD, 0x62, 0, 0])

        let command = Api.BotCommand.botCommand(Api.BotCommand.Cons_botCommand(flags: 0, command: text, description: "d"))
        let serialized = swiftSerialized(command)
        XCTAssertEqual(serialized.subdata(in: 8 ..< 16), expected)

        let (_, buffer, _) = Api.functions.contacts.search(flags: 0, q: text, limit: 1)
        XCTAssertEqual(buffer.makeData().subdata(in: 8 ..< 16), expected)
    }
}
