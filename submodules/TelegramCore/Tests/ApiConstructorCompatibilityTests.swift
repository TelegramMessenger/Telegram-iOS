import XCTest
import TelegramApi
@testable import TelegramCore

private func appendTLBytes(_ bytes: Data, to buffer: Buffer) {
    var encoded = Data()
    if bytes.count < 254 {
        encoded.append(UInt8(bytes.count))
    } else {
        encoded.append(254)
        encoded.append(UInt8(bytes.count & 0xff))
        encoded.append(UInt8((bytes.count >> 8) & 0xff))
        encoded.append(UInt8((bytes.count >> 16) & 0xff))
    }
    encoded.append(bytes)
    while encoded.count % 4 != 0 {
        encoded.append(0)
    }
    encoded.withUnsafeBytes { pointer in
        buffer.appendBytes(pointer.baseAddress!, length: UInt(encoded.count))
    }
}

final class ApiConstructorCompatibilityTests: XCTestCase {
    private func userFullBytes(constructor: Int32, flags2: Int32, gramAddress: String?) -> Buffer {
        let buffer = Buffer()
        buffer.appendInt32(constructor)
        buffer.appendInt32(0)
        buffer.appendInt32(flags2)
        buffer.appendInt64(777)
        Api.PeerSettings.peerSettings(Api.PeerSettings.Cons_peerSettings(flags: 0, geoDistance: nil, requestChatTitle: nil, requestChatDate: nil, businessBotId: nil, businessBotManageUrl: nil, chargePaidMessageStars: nil, registrationMonth: nil, phoneCountry: nil, nameChangeDate: nil, photoChangeDate: nil)).serialize(buffer, true)
        Api.PeerNotifySettings.peerNotifySettings(Api.PeerNotifySettings.Cons_peerNotifySettings(flags: 0, showPreviews: nil, silent: nil, muteUntil: nil, iosSound: nil, androidSound: nil, otherSound: nil, storiesMuted: nil, storiesHideSender: nil, storiesIosSound: nil, storiesAndroidSound: nil, storiesOtherSound: nil)).serialize(buffer, true)
        buffer.appendInt32(5)
        if let gramAddress {
            appendTLBytes(gramAddress.data(using: .utf8)!, to: buffer)
        }
        return buffer
    }

    private func parsedUserFull(_ buffer: Buffer) -> Api.UserFull.Cons_userFull? {
        buffer.appendInt32(0x0badf00d)
        let reader = BufferReader(buffer)
        guard let signature = reader.readInt32(), let value = Api.parse(reader, signature: signature) as? Api.UserFull, case let .userFull(data) = value else {
            return nil
        }
        XCTAssertEqual(reader.readInt32(), 0x0badf00d, "the parser must consume exactly the userFull bytes")
        return data
    }

    func testUserFullParsesWithAndWithoutTheGramAddressLayout() {
        let current = parsedUserFull(self.userFullBytes(constructor: 114026053, flags2: 0, gramAddress: nil))
        XCTAssertEqual(current?.id, 777)
        XCTAssertEqual(current?.commonChatsCount, 5)

        let previous = parsedUserFull(self.userFullBytes(constructor: 2145859780, flags2: 0, gramAddress: nil))
        XCTAssertEqual(previous?.id, 777, "the layout production still sends at this layer")
        XCTAssertEqual(previous?.commonChatsCount, 5)

        let previousWithAddress = parsedUserFull(self.userFullBytes(constructor: 2145859780, flags2: 1 << 27, gramAddress: "UQAddress"))
        XCTAssertEqual(previousWithAddress?.id, 777)
        XCTAssertEqual(previousWithAddress?.commonChatsCount, 5)
    }

    func testWalletUserAddressParsesBothLayouts() {
        let previous = Buffer()
        previous.appendInt32(-1581738523)
        previous.appendInt64(42)
        appendTLBytes("UQAddress".data(using: .utf8)!, to: previous)
        appendTLBytes(Data([1, 2, 3]), to: previous)
        guard let parsedPrevious = Api.parse(previous) as? Api.WalletUserAddress, case let .walletUserAddress(previousData) = parsedPrevious else {
            return XCTFail("the previous walletUserAddress layout must still parse")
        }
        XCTAssertEqual(previousData.flags, 1 << 0)
        XCTAssertEqual(previousData.userId, 42)
        XCTAssertEqual(previousData.address, "UQAddress")
        XCTAssertEqual(previousData.publicKey.makeData(), Data([1, 2, 3]))

        let current = Buffer()
        Api.WalletUserAddress.walletUserAddress(Api.WalletUserAddress.Cons_walletUserAddress(flags: 0, userId: nil, address: "UQOther", publicKey: Buffer(data: Data([4])))).serialize(current, true)
        guard let parsedCurrent = Api.parse(current) as? Api.WalletUserAddress, case let .walletUserAddress(currentData) = parsedCurrent else {
            return XCTFail("the current walletUserAddress layout must parse")
        }
        XCTAssertNil(currentData.userId)
        XCTAssertEqual(currentData.address, "UQOther")
    }
}
