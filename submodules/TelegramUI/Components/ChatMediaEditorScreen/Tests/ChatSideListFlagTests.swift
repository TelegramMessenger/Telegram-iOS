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
        isSidebarForum: Bool = false,
        isMonoforum: Bool = false,
        isAdminMonoforum: Bool = false,
        isSidebarBot: Bool = false,
        enabled: Bool = true
    ) -> ChatSideListKind? {
        return chatSideListKind(
            peerId: peerId,
            accountPeerId: self.accountPeerId,
            isForum: isForum,
            isSidebarForum: isSidebarForum,
            isMonoforum: isMonoforum,
            isAdminMonoforum: isAdminMonoforum,
            isSidebarBot: isSidebarBot,
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

    func testSidebarBot() {
        let value = self.kind(peerId: self.botPeerId, isSidebarBot: true)
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

    func testSidebarForum() {
        let value = self.kind(peerId: self.channelPeerId, isForum: true, isSidebarForum: true)
        XCTAssertEqual(value, .forum(peerId: self.channelPeerId))
        XCTAssertEqual(value?.listLocation, .forum(peerId: self.channelPeerId))
        XCTAssertEqual(value?.parentPeerId, self.channelPeerId)
        XCTAssertEqual(value?.showsNewTopicButton, true)
    }

    func testSidebarForumDisabled() {
        XCTAssertNil(self.kind(peerId: self.channelPeerId, isForum: true, isSidebarForum: true, enabled: false))
    }

    func testForumTopicSelectionSwitches() {
        let value = chatSideListSelection(kind: .forum(peerId: self.channelPeerId), currentThreadId: 1, selectedPeerId: self.channelPeerId, selectedThreadId: 4, messageId: nil)
        XCTAssertEqual(value, .switchThread(4, messageId: nil))
    }

    func testDisabledReturnsNil() {
        XCTAssertNil(self.kind(peerId: self.accountPeerId, enabled: false))
        XCTAssertNil(self.kind(peerId: self.botPeerId, isSidebarBot: true, enabled: false))
        XCTAssertNil(self.kind(peerId: self.channelPeerId, isMonoforum: true, isAdminMonoforum: true, enabled: false))
    }

    private let otherUserPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(4))
    private let messageId = EngineMessage.Id(peerId: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(2)), namespace: Namespaces.Message.Cloud, id: 10)

    func testSelectionOtherThreadSwitches() {
        let value = chatSideListSelection(kind: .botThreads(peerId: self.botPeerId), currentThreadId: 5, selectedPeerId: self.botPeerId, selectedThreadId: 6, messageId: nil)
        XCTAssertEqual(value, .switchThread(6, messageId: nil))
    }

    func testSelectionSameThreadClosesOnly() {
        let value = chatSideListSelection(kind: .botThreads(peerId: self.botPeerId), currentThreadId: 5, selectedPeerId: self.botPeerId, selectedThreadId: 5, messageId: nil)
        XCTAssertEqual(value, .closeOnly)
    }

    func testSelectionSameThreadWithMessageSwitches() {
        let value = chatSideListSelection(kind: .botThreads(peerId: self.botPeerId), currentThreadId: 5, selectedPeerId: self.botPeerId, selectedThreadId: 5, messageId: self.messageId)
        XCTAssertEqual(value, .switchThread(5, messageId: self.messageId))
    }

    func testSelectionForeignPeerPassesThrough() {
        let value = chatSideListSelection(kind: .savedMessages(peerId: self.accountPeerId), currentThreadId: nil, selectedPeerId: self.otherUserPeerId, selectedThreadId: nil, messageId: nil)
        XCTAssertEqual(value, .passThrough)
    }

    func testSavedMessagesAllMessagesIsNilThread() {
        let value = chatSideListSelection(kind: .savedMessages(peerId: self.accountPeerId), currentThreadId: 7, selectedPeerId: self.accountPeerId, selectedThreadId: nil, messageId: nil)
        XCTAssertEqual(value, .switchThread(nil, messageId: nil))
    }

    func testSavedListRowMapsToParentThread() {
        let value = chatSideListResolvedSelection(location: .savedMessagesChats(peerId: self.accountPeerId), peerId: self.otherUserPeerId, threadId: nil, isListRow: true)
        XCTAssertEqual(value.peerId, self.accountPeerId)
        XCTAssertEqual(value.threadId, self.otherUserPeerId.toInt64())
    }

    func testSavedListMyNotesRowMapsToOwnThread() {
        let value = chatSideListResolvedSelection(location: .savedMessagesChats(peerId: self.accountPeerId), peerId: self.accountPeerId, threadId: nil, isListRow: true)
        XCTAssertEqual(value.peerId, self.accountPeerId)
        XCTAssertEqual(value.threadId, self.accountPeerId.toInt64())
    }

    func testSavedSearchPeerHitMapsToParentThread() {
        let value = chatSideListResolvedSelection(location: .savedMessagesChats(peerId: self.channelPeerId), peerId: self.otherUserPeerId, threadId: nil, isListRow: false)
        XCTAssertEqual(value.peerId, self.channelPeerId)
        XCTAssertEqual(value.threadId, self.otherUserPeerId.toInt64())
    }

    func testSearchHitWithThreadIsUnchanged() {
        let value = chatSideListResolvedSelection(location: .savedMessagesChats(peerId: self.accountPeerId), peerId: self.accountPeerId, threadId: 9, isListRow: false)
        XCTAssertEqual(value.peerId, self.accountPeerId)
        XCTAssertEqual(value.threadId, 9)
    }

    func testForumLocationIsUnchanged() {
        let value = chatSideListResolvedSelection(location: .forum(peerId: self.botPeerId), peerId: self.botPeerId, threadId: 3, isListRow: true)
        XCTAssertEqual(value.peerId, self.botPeerId)
        XCTAssertEqual(value.threadId, 3)
    }
}
