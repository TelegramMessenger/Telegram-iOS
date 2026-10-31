import XCTest
import TelegramCore

final class WalletTransferMessageRecipientTests: XCTestCase {
    private let accountPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))
    private let address = "UQCs-9jTqHhC1xYQ8dTnB8cKpXbR4ZtW2FgJ5nMvLe0aMITE"

    private func user(_ id: Int64, firstName: String? = "User", botInfo: BotUserInfo? = nil, flags: UserInfoFlags = []) -> EnginePeer {
        return EnginePeer(TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id)), accessHash: nil, firstName: firstName, lastName: nil, username: nil, phone: nil, photo: [], botInfo: botInfo, restrictionInfo: nil, flags: flags, emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
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
        XCTAssertEqual(walletTransferMessageRecipient(chatPeer: self.user(777000), accountPeerId: self.accountPeerId, peerAddress: self.address), .address(self.address))
    }

    func testTransferInTelegramNotificationsWithoutAddressHasNoRecipient() {
        XCTAssertNil(walletTransferMessageRecipient(chatPeer: self.user(777000), accountPeerId: self.accountPeerId, peerAddress: ""))
        XCTAssertNil(walletTransferMessageRecipient(chatPeer: self.user(777000), accountPeerId: self.accountPeerId, peerAddress: "  \n"))
    }

    func testAddressIsTrimmed() {
        XCTAssertEqual(walletTransferMessageRecipient(chatPeer: self.user(777000), accountPeerId: self.accountPeerId, peerAddress: " \(self.address)\n"), .address(self.address))
    }

    func testServiceAccountsBotsAndDeletedAccountsAreNeverRecipients() {
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
            XCTAssertEqual(walletTransferMessageRecipient(chatPeer: peer, accountPeerId: self.accountPeerId, peerAddress: self.address), .address(self.address), "\(peer.id)")
            XCTAssertNil(walletTransferMessageRecipient(chatPeer: peer, accountPeerId: self.accountPeerId, peerAddress: ""), "\(peer.id)")
        }
    }

    func testMissingChatPeerFallsBackToTheAddress() {
        XCTAssertEqual(walletTransferMessageRecipient(chatPeer: nil, accountPeerId: self.accountPeerId, peerAddress: self.address), .address(self.address))
        XCTAssertNil(walletTransferMessageRecipient(chatPeer: nil, accountPeerId: self.accountPeerId, peerAddress: ""))
    }
}
