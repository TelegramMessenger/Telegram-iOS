import Foundation
import XCTest
@testable import TelegramApi

final class NoPaidMessagesTokenTests: XCTestCase {
    func testRequiredURLAndNewExpiryFlagRoundTrip() throws {
        for expires: Int32? in [nil, 1800000000] {
            let url = "https://t.me/contact/XXXX:YYYZZZ?free=AABBCC"
            let value = Api.ExportedNoPaidMessagesToken.exportedNoPaidMessagesToken(.init(flags: expires == nil ? 0 : 1, token: "AABBCC", url: url, expires: expires))
            let buffer = Buffer()
            Api.serializeObject(value, buffer: buffer, boxed: true)
            XCTAssertEqual(Array(buffer.makeData().prefix(4)), [0x42, 0xd0, 0x5d, 0x69])
            let result = try XCTUnwrap(Api.parse(buffer) as? Api.ExportedNoPaidMessagesToken)
            guard case let .exportedNoPaidMessagesToken(data) = result else { return XCTFail("Wrong constructor") }
            XCTAssertEqual(data.token, "AABBCC")
            XCTAssertEqual(data.url, url)
            XCTAssertEqual(data.expires, expires)
        }
    }
}
