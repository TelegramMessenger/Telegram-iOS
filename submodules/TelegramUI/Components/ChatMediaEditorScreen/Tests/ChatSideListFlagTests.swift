import XCTest
import TelegramCore
import AccountContext

final class ChatSideListFlagTests: XCTestCase {
    private let accountPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))
    private let botPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(2))
    private let channelPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(3))

    private func kind(
        peerId: EnginePeer.Id,
        isForum: Bool = false,
        isMonoforum: Bool = false,
        isAdminMonoforum: Bool = false,
        isBotWithThreads: Bool = false,
        isRegularWidth: Bool = false,
        enabled: Bool = true
    ) -> ChatSideListKind? {
        return chatSideListKind(
            peerId: peerId,
            accountPeerId: self.accountPeerId,
            isForum: isForum,
            isMonoforum: isMonoforum,
            isAdminMonoforum: isAdminMonoforum,
            isBotWithThreads: isBotWithThreads,
            isRegularWidth: isRegularWidth,
            enabled: enabled
        )
    }

    func testOnByDefault() {
        XCTAssertTrue(chatSideListEnabled(legacyOverride: false, killswitchPresent: false))
    }

    func testLegacyOverrideDisables() {
        XCTAssertFalse(chatSideListEnabled(legacyOverride: true, killswitchPresent: false))
    }

    func testKillswitchDisables() {
        XCTAssertFalse(chatSideListEnabled(legacyOverride: false, killswitchPresent: true))
        XCTAssertFalse(chatSideListEnabled(legacyOverride: true, killswitchPresent: true))
    }

    func testKillswitchKey() {
        XCTAssertEqual(chatSideListKillswitchKey, "ios_killswitch_disable_chat_side_list")
    }

    func testSavedMessages() {
        let value = self.kind(peerId: self.accountPeerId)
        XCTAssertEqual(value, .savedMessages(peerId: self.accountPeerId))
        XCTAssertEqual(value?.listLocation, .savedMessagesChats(peerId: self.accountPeerId))
        XCTAssertEqual(value?.parentPeerId, self.accountPeerId)
        XCTAssertEqual(value?.showsNewTopicButton, false)
    }

    func testAdminMonoforum() {
        let value = self.kind(peerId: self.channelPeerId, isMonoforum: true, isAdminMonoforum: true)
        XCTAssertEqual(value, .monoforum(peerId: self.channelPeerId))
        XCTAssertEqual(value?.listLocation, .savedMessagesChats(peerId: self.channelPeerId))
        XCTAssertEqual(value?.showsNewTopicButton, false)
    }

    func testNonAdminMonoforum() {
        XCTAssertNil(self.kind(peerId: self.channelPeerId, isMonoforum: true, isAdminMonoforum: false))
    }

    func testBotThreads() {
        let value = self.kind(peerId: self.botPeerId, isBotWithThreads: true)
        XCTAssertEqual(value, .botThreads(peerId: self.botPeerId))
        XCTAssertEqual(value?.listLocation, .forum(peerId: self.botPeerId))
        XCTAssertEqual(value?.showsNewTopicButton, true)
    }

    func testPlainBotExcluded() {
        XCTAssertNil(self.kind(peerId: self.botPeerId))
    }

    func testForumExcluded() {
        XCTAssertNil(self.kind(peerId: self.channelPeerId, isForum: true))
    }

    func testRegularWidthExcluded() {
        XCTAssertNil(self.kind(peerId: self.accountPeerId, isRegularWidth: true))
        XCTAssertNil(self.kind(peerId: self.botPeerId, isBotWithThreads: true, isRegularWidth: true))
    }

    func testDisabledReturnsNil() {
        XCTAssertNil(self.kind(peerId: self.accountPeerId, enabled: false))
        XCTAssertNil(self.kind(peerId: self.botPeerId, isBotWithThreads: true, enabled: false))
        XCTAssertNil(self.kind(peerId: self.channelPeerId, isMonoforum: true, isAdminMonoforum: true, enabled: false))
    }
}
