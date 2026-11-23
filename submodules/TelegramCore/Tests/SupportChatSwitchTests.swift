import XCTest
import Postbox
@testable import TelegramCore

/// Next and previous walk the list the agent sees: unread chats only, from the current row, never
/// past what the list shows. A folder orders its own pinned chats first and every other chat by date.
final class SupportChatSwitchTests: XCTestCase {
    private func peerId(_ value: Int64) -> PeerId {
        return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(value))
    }

    private func messageIndex(_ peer: Int64, _ timestamp: Int32) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: self.peerId(peer), namespace: Namespaces.Message.Cloud, id: timestamp), timestamp: timestamp)
    }

    private func row(_ peer: Int64, _ timestamp: Int32, pinningIndex: UInt16? = nil) -> ChatListIndex {
        return ChatListIndex(pinningIndex: pinningIndex, messageIndex: self.messageIndex(peer, timestamp))
    }

    private func group(_ rows: [ChatListIndex], topHole: MessageIndex? = nil, isListed: @escaping (ChatListIndex) -> Bool = { _ in true }) -> SupportSwitchGroup {
        let sorted = rows.sorted()
        return SupportSwitchGroup(
            topHole: topHole,
            pinnedRows: rows.filter { $0.pinningIndex != nil },
            isListed: isListed,
            walk: { after, downward, f in
                let walked = downward ? Array(sorted.filter { $0 < after }.reversed()) : sorted.filter { $0 > after }
                for index in walked {
                    if !f(index) {
                        return
                    }
                }
            }
        )
    }

    private func unread(_ peers: Int64...) -> (PeerId) -> Bool {
        let ids = Set(peers.map { self.peerId($0) })
        return { ids.contains($0) }
    }

    private func listTarget(current: ChatListIndex, downward: Bool, group: SupportSwitchGroup, isTarget: (PeerId) -> Bool) -> PeerId? {
        return supportListSwitchTarget(current: current, downward: downward, group: group, isTarget: isTarget)
    }

    private func folderTarget(peer: Int64, current: ChatListIndex?, downward: Bool, pinned: [Int64] = [], named: [Int64] = [], groups: [SupportSwitchGroup], isTarget: (PeerId) -> Bool) -> PeerId? {
        let namedIds = Set((named + pinned).map { self.peerId($0) })
        return supportFolderSwitchTarget(peerId: self.peerId(peer), current: current, downward: downward, pinnedPeerIds: pinned.map { self.peerId($0) }, namesAnyPeer: !named.isEmpty, isNamed: { namedIds.contains($0) }, groups: groups, isTarget: isTarget)
    }

    func testNextIsTheFirstUnreadRowBelow() {
        let rows = [self.row(1, 500), self.row(2, 400), self.row(3, 300), self.row(4, 200)]
        XCTAssertEqual(self.listTarget(current: rows[1], downward: true, group: self.group(rows), isTarget: self.unread(1, 4)), self.peerId(4))
    }

    func testPreviousIsTheFirstUnreadRowAbove() {
        let rows = [self.row(1, 500), self.row(2, 400), self.row(3, 300), self.row(4, 200)]
        XCTAssertEqual(self.listTarget(current: rows[3], downward: false, group: self.group(rows), isTarget: self.unread(1, 2)), self.peerId(2))
    }

    func testNoUnreadChatLeftGivesNothing() {
        let rows = [self.row(1, 500), self.row(2, 400), self.row(3, 300)]
        XCTAssertNil(self.listTarget(current: rows[1], downward: true, group: self.group(rows), isTarget: self.unread(1)))
        XCTAssertNil(self.listTarget(current: rows[1], downward: false, group: self.group(rows), isTarget: self.unread(3)))
    }

    func testLastRowHasNoNextAndFirstRowHasNoPrevious() {
        let rows = [self.row(1, 500), self.row(2, 400)]
        XCTAssertNil(self.listTarget(current: rows[1], downward: true, group: self.group(rows), isTarget: self.unread(1, 2)))
        XCTAssertNil(self.listTarget(current: rows[0], downward: false, group: self.group(rows), isTarget: self.unread(1, 2)))
    }

    func testPinnedRowsComeBeforeTheRest() {
        let pinned = self.row(1, 100, pinningIndex: 0)
        let rows = [pinned, self.row(2, 500), self.row(3, 400)]
        XCTAssertEqual(self.listTarget(current: pinned, downward: true, group: self.group(rows), isTarget: self.unread(3)), self.peerId(3))
        XCTAssertEqual(self.listTarget(current: rows[2], downward: false, group: self.group(rows), isTarget: self.unread(1)), self.peerId(1))
    }

    func testTheWalkStopsAtTheTopHole() {
        let rows = [self.row(1, 500), self.row(2, 400), self.row(3, 200)]
        let group = self.group(rows, topHole: self.messageIndex(9, 300))
        XCTAssertNil(self.listTarget(current: rows[0], downward: true, group: group, isTarget: self.unread(3)))
        XCTAssertEqual(self.listTarget(current: rows[0], downward: true, group: group, isTarget: self.unread(2, 3)), self.peerId(2))
    }

    func testAChatTheListDoesNotShowHasNoNeighbours() {
        let rows = [self.row(1, 500), self.row(3, 200), self.row(4, 100)]
        let group = self.group(rows, topHole: self.messageIndex(9, 300))
        XCTAssertNil(self.listTarget(current: rows[1], downward: true, group: group, isTarget: self.unread(1, 4)))
        XCTAssertNil(self.listTarget(current: rows[1], downward: false, group: group, isTarget: self.unread(1, 4)))
    }

    func testFolderSkipsChatsItDoesNotList() {
        let rows = [self.row(1, 500), self.row(2, 400), self.row(3, 300)]
        let two = self.peerId(2)
        let group = self.group(rows, isListed: { $0.messageIndex.id.peerId != two })
        XCTAssertEqual(self.folderTarget(peer: 1, current: rows[0], downward: true, groups: [group], isTarget: self.unread(2, 3)), self.peerId(3))
    }

    func testFolderTreatsMainListPinsAsOrdinaryRows() {
        let mainPinned = self.row(2, 300, pinningIndex: 0)
        let rows = [mainPinned, self.row(1, 500), self.row(3, 400), self.row(4, 200)]
        let group = self.group(rows)
        XCTAssertEqual(self.folderTarget(peer: 3, current: rows[2], downward: true, groups: [group], isTarget: self.unread(2, 4)), self.peerId(2))
        XCTAssertEqual(self.folderTarget(peer: 4, current: rows[3], downward: false, groups: [group], isTarget: self.unread(2, 1)), self.peerId(2))
    }

    func testFolderPinnedChatsComeFirstInTheirOwnOrder() {
        let rows = [self.row(1, 500), self.row(2, 400), self.row(3, 300), self.row(4, 200)]
        let group = self.group(rows)
        XCTAssertEqual(self.folderTarget(peer: 3, current: rows[2], downward: true, pinned: [3, 1], groups: [group], isTarget: self.unread(1, 2)), self.peerId(1))
        XCTAssertEqual(self.folderTarget(peer: 1, current: rows[0], downward: true, pinned: [3, 1], groups: [group], isTarget: self.unread(2, 4)), self.peerId(2))
        XCTAssertEqual(self.folderTarget(peer: 2, current: rows[1], downward: false, pinned: [3, 1], groups: [group], isTarget: self.unread(3, 1)), self.peerId(1))
        XCTAssertNil(self.folderTarget(peer: 3, current: rows[2], downward: false, pinned: [3, 1], groups: [group], isTarget: self.unread(2)))
    }

    func testFolderMergesItsGroupsByDate() {
        let root = [self.row(1, 500), self.row(2, 300)]
        let archive = [self.row(3, 400), self.row(4, 200)]
        let groups = [self.group(root), self.group(archive)]
        XCTAssertEqual(self.folderTarget(peer: 1, current: root[0], downward: true, groups: groups, isTarget: self.unread(2, 3, 4)), self.peerId(3))
        XCTAssertEqual(self.folderTarget(peer: 4, current: archive[1], downward: false, groups: groups, isTarget: self.unread(1, 2, 3)), self.peerId(2))
    }

    func testFolderKeepsOnlyNamedChatsBelowAHole() {
        let rows = [self.row(1, 500), self.row(2, 200), self.row(3, 100)]
        let group = self.group(rows, topHole: self.messageIndex(9, 300))
        XCTAssertEqual(self.folderTarget(peer: 1, current: rows[0], downward: true, named: [3], groups: [group], isTarget: self.unread(2, 3)), self.peerId(3))
        XCTAssertNil(self.folderTarget(peer: 1, current: rows[0], downward: true, groups: [group], isTarget: self.unread(2, 3)))
    }

    func testFolderChatTheListDoesNotShowHasNoNeighbours() {
        let rows = [self.row(1, 500), self.row(2, 200)]
        let group = self.group(rows, topHole: self.messageIndex(9, 300))
        XCTAssertNil(self.folderTarget(peer: 2, current: rows[1], downward: false, groups: [group], isTarget: self.unread(1)))
        XCTAssertEqual(self.folderTarget(peer: 2, current: rows[1], downward: false, named: [2], groups: [group], isTarget: self.unread(1)), self.peerId(1))
    }

    func testFolderWithoutARowForTheCurrentChatGivesNothing() {
        let rows = [self.row(1, 500)]
        XCTAssertNil(self.folderTarget(peer: 2, current: nil, downward: true, groups: [self.group(rows)], isTarget: self.unread(1)))
    }

    func testDoneOpensTheTargetWhenThereIsOne() {
        let target = EnginePeer(TelegramUser(id: self.peerId(1), accessHash: nil, firstName: "A", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
        guard case let .switchTo(peer) = supportDoneResult(behavior: .next, target: target) else {
            XCTFail("expected a switch")
            return
        }
        XCTAssertEqual(peer.id, self.peerId(1))
    }

    func testDoneWithNoTargetTellsNoneIsLeftOnlyWhenSwitchingIsOn() {
        for behavior in [SupportSwitchBehavior.next, .previous] {
            guard case .noUnreadChatLeft = supportDoneResult(behavior: behavior, target: nil) else {
                XCTFail("expected none left for \(behavior)")
                return
            }
        }
        guard case .stay = supportDoneResult(behavior: .none, target: nil) else {
            XCTFail("expected stay")
            return
        }
    }

    func testDeferredSendsAreRecognised() {
        XCTAssertTrue(supportSendIsDeferred(attributes: [OutgoingScheduleInfoMessageAttribute(scheduleTime: 100, repeatPeriod: nil)]))
        XCTAssertFalse(supportSendIsDeferred(attributes: []))
    }
}
