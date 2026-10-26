import Foundation
import XCTest
@testable import TelegramApi

final class WalletTelegramGiftPeerTests: XCTestCase {
    func testTelegramGiftPeerWireFormat() throws {
        for flags: Int32 in [0, 1] {
            let bytes = Data([0x99, 0x94, 0x72, 0xf4, UInt8(flags), 0, 0, 0])
            let parsed = try XCTUnwrap(Api.parse(Buffer(data: bytes)) as? Api.WalletTransactionPeer)
            guard case let .walletTransactionPeerTelegramGift(peer) = parsed else {
                return XCTFail("Expected a Telegram gift peer")
            }
            XCTAssertEqual(peer.flags, flags)
            let output = Buffer()
            Api.serializeObject(parsed, buffer: output, boxed: true)
            XCTAssertEqual(output.makeData(), bytes)
        }
    }

    func testTelegramGiftPeerRequiresFlags() {
        XCTAssertNil(Api.parse(Buffer(data: Data([0x99, 0x94, 0x72, 0xf4]))))
    }
}
