import XCTest
import Postbox
@testable import TelegramCore

/// A support account removes old one-to-one chats locally, read or unread. Everything the server
/// cannot give back, or that would be fetched again on every launch, stays.
final class SupportChatListCleanupTests: XCTestCase {
    private func chat(
        isOneToOne: Bool = true,
        isAccountPeer: Bool = false,
        isServiceUser: Bool = false,
        isNamedByFolder: Bool = false,
        isPinned: Bool = false,
        hasStoredComposerState: Bool = false,
        hasUnsentMessages: Bool = false,
        hasOpenHistoryView: Bool = false
    ) -> SupportChatListCleanupChatInfo {
        return SupportChatListCleanupChatInfo(isOneToOne: isOneToOne, isAccountPeer: isAccountPeer, isServiceUser: isServiceUser, isNamedByFolder: isNamedByFolder, isPinned: isPinned, hasStoredComposerState: hasStoredComposerState, hasUnsentMessages: hasUnsentMessages, hasOpenHistoryView: hasOpenHistoryView)
    }

    func testPlainOneToOneChatIsRemoved() {
        XCTAssertTrue(supportChatListCleanupRemovesChat(self.chat()))
    }

    func testGroupsChannelsAndSecretChatsStay() {
        XCTAssertFalse(supportChatListCleanupRemovesChat(self.chat(isOneToOne: false)))
    }

    func testSavedMessagesAndServiceChatStay() {
        XCTAssertFalse(supportChatListCleanupRemovesChat(self.chat(isAccountPeer: true)))
        XCTAssertFalse(supportChatListCleanupRemovesChat(self.chat(isServiceUser: true)))
    }

    func testChatNamedByAFolderStays() {
        XCTAssertFalse(supportChatListCleanupRemovesChat(self.chat(isNamedByFolder: true)))
    }

    func testPinnedChatStays() {
        XCTAssertFalse(supportChatListCleanupRemovesChat(self.chat(isPinned: true)))
    }

    func testStoredComposerStateStays() {
        XCTAssertFalse(supportChatListCleanupRemovesChat(self.chat(hasStoredComposerState: true)))
    }

    func testUnsentMessagesStay() {
        XCTAssertFalse(supportChatListCleanupRemovesChat(self.chat(hasUnsentMessages: true)))
    }

    func testChatOpenOnScreenStays() {
        XCTAssertFalse(supportChatListCleanupRemovesChat(self.chat(hasOpenHistoryView: true)))
    }

    func testARowWithNewerMessagesIsHeld() {
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))
        func index(_ timestamp: Int32) -> MessageIndex {
            return MessageIndex(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: timestamp), timestamp: timestamp)
        }
        XCTAssertTrue(supportChatListCleanupRowIsHeld(rowIndex: index(100), topMessageIndex: index(200)))
        XCTAssertFalse(supportChatListCleanupRowIsHeld(rowIndex: index(100), topMessageIndex: index(100)))
        XCTAssertFalse(supportChatListCleanupRowIsHeld(rowIndex: index(200), topMessageIndex: index(100)))
        XCTAssertFalse(supportChatListCleanupRowIsHeld(rowIndex: index(100), topMessageIndex: nil))
    }

    func testVacuumNeedsManyRemovedChatsAndFreeSpace() {
        let gigabyte: Int64 = 1024 * 1024 * 1024
        XCTAssertTrue(supportChatListCleanupRunsVacuum(removedChatCount: 10000, databaseSize: gigabyte, freeSpace: 2 * gigabyte))
        XCTAssertFalse(supportChatListCleanupRunsVacuum(removedChatCount: 9999, databaseSize: gigabyte, freeSpace: 2 * gigabyte))
        XCTAssertFalse(supportChatListCleanupRunsVacuum(removedChatCount: 10000, databaseSize: gigabyte, freeSpace: 2 * gigabyte - 1))
    }
}
