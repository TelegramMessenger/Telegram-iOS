import XCTest
import TelegramCore
import WalletContext

final class WalletTransferMessageRecipientTests: XCTestCase {
    private let accountPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))
    // The mainnet zero address, a valid user-friendly address with its checksum.
    private let address = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"

    private func user(_ id: Int64, firstName: String? = "User", botInfo: BotUserInfo? = nil, flags: UserInfoFlags = []) -> EnginePeer {
        return EnginePeer(TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id)), accessHash: nil, firstName: firstName, lastName: nil, username: nil, phone: nil, photo: [], botInfo: botInfo, restrictionInfo: nil, flags: flags, emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
    }

    private var normalizedAddress: String {
        guard let normalized = WalletContext.transferAddress(from: self.address, preserveBounce: true) else {
            XCTFail("the test address does not parse")
            return ""
        }
        return normalized
    }

    func testTransferInPrivateChatKeepsTheUserAsRecipient() {
        let peer = self.user(2)
        XCTAssertEqual(walletTransferMessageRecipient(chatPeer: peer, accountPeerId: self.accountPeerId, peerAddress: self.address), .peer(peer))
    }

    func testTransferInPrivateChatWithoutAddressKeepsTheUserAsRecipient() {
        let peer = self.user(2)
        XCTAssertEqual(walletTransferMessageRecipient(chatPeer: peer, accountPeerId: self.accountPeerId, peerAddress: ""), .peer(peer))
    }

    func testIncomingTransferInTelegramNotificationsTargetsTheSenderAddress() {
        XCTAssertEqual(walletTransferMessageRecipient(chatPeer: self.user(777000), accountPeerId: self.accountPeerId, peerAddress: self.address), .address(self.normalizedAddress))
    }

    func testTransferInTelegramNotificationsWithoutAddressHasNoRecipient() {
        XCTAssertNil(walletTransferMessageRecipient(chatPeer: self.user(777000), accountPeerId: self.accountPeerId, peerAddress: ""))
        XCTAssertNil(walletTransferMessageRecipient(chatPeer: self.user(777000), accountPeerId: self.accountPeerId, peerAddress: "  \n"))
    }

    func testTransferInTelegramNotificationsWithAnAddressThatDoesNotParseHasNoRecipient() {
        XCTAssertNil(walletTransferMessageRecipient(chatPeer: self.user(777000), accountPeerId: self.accountPeerId, peerAddress: "not an address"))
        XCTAssertNil(walletTransferMessageRecipient(chatPeer: self.user(777000), accountPeerId: self.accountPeerId, peerAddress: String(self.address.dropLast())))
    }

    func testAddressIsTrimmed() {
        XCTAssertEqual(walletTransferMessageRecipient(chatPeer: self.user(777000), accountPeerId: self.accountPeerId, peerAddress: " \(self.address)\n"), .address(self.normalizedAddress))
    }

    func testOtherServiceAccountsBotsDeletedAccountsAndTheAccountItselfHaveNoRecipient() {
        let candidates: [EnginePeer] = [
            self.user(333000),
            self.user(489000),
            self.user(1271266957),
            self.user(3, flags: [.isSupport]),
            self.user(4, botInfo: BotUserInfo(flags: [], inlinePlaceholder: nil)),
            self.user(5, firstName: nil),
            self.user(1)
        ]
        for peer in candidates {
            XCTAssertNil(walletTransferMessageRecipient(chatPeer: peer, accountPeerId: self.accountPeerId, peerAddress: self.address), "\(peer.id)")
            XCTAssertNil(walletTransferMessageRecipient(chatPeer: peer, accountPeerId: self.accountPeerId, peerAddress: ""), "\(peer.id)")
        }
    }

    func testTransferInAGroupHasNoRecipient() {
        let group = EnginePeer(TelegramGroup(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: EnginePeer.Id.Id._internalFromInt64Value(6)), title: "Group", photo: [], participantCount: 2, role: .member, membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0))
        XCTAssertNil(walletTransferMessageRecipient(chatPeer: group, accountPeerId: self.accountPeerId, peerAddress: self.address))
    }

    func testMissingChatPeerHasNoRecipient() {
        XCTAssertNil(walletTransferMessageRecipient(chatPeer: nil, accountPeerId: self.accountPeerId, peerAddress: self.address))
        XCTAssertNil(walletTransferMessageRecipient(chatPeer: nil, accountPeerId: self.accountPeerId, peerAddress: ""))
    }
}
